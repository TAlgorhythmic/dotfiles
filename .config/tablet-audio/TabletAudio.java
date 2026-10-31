import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioTimestamp;
import android.media.AudioTrack;
import android.os.Process;
import java.io.FileDescriptor;
import java.io.FileInputStream;
import java.io.IOException;

/** Plays s16le stereo PCM from stdin through AudioFlinger, so session-0 effects (Dirac) apply. */
public class TabletAudio {
    static final int RATE = 44100, FRAME_BYTES = 4, CHUNK_FRAMES = 256;
    static final long SAMPLE_NANOS = 200_000_000L, SETTLE_NANOS = 2_000_000_000L;
    static final int SAMPLES_PER_DECISION = 5, MAX_CORRECTION_FRAMES = 5;
    static final int DEADBAND_FRAMES = RATE * 5 / 1000, MAX_BACKLOG_FRAMES = RATE * 30 / 1000;

    public static void main(String[] args) throws IOException {
        int targetFrames = Integer.parseInt(args[0]) * RATE / 1000;
        try {
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO);
        } catch (RuntimeException e) {
            System.err.println("no audio priority: " + e);
        }

        int minBytes = AudioTrack.getMinBufferSize(RATE, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT);
        AudioTrack track = new AudioTrack(
            new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build(),
            new AudioFormat.Builder()
                .setSampleRate(RATE)
                .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .build(),
            Math.max(minBytes, targetFrames * 2 * FRAME_BYTES),
            AudioTrack.MODE_STREAM,
            android.media.AudioManager.AUDIO_SESSION_ID_GENERATE);

        // A startup burst would otherwise sit in a larger buffer for the whole session.
        track.setBufferSizeInFrames(targetFrames);

        FileInputStream in = new FileInputStream(FileDescriptor.in);
        byte[] chunk = new byte[CHUNK_FRAMES * FRAME_BYTES];
        byte[] stretched = new byte[(CHUNK_FRAMES + 1) * FRAME_BYTES];
        AudioTimestamp timestamp = new AudioTimestamp();
        long written = 0, playStart = 0, lastSample = 0, delaySum = 0, baseline = -1, corrections = 0;
        int samples = 0, pendingCorrection = 0;

        while (readChunk(in, chunk)) {
            if (pendingCorrection == 0) {
                track.write(chunk, 0, chunk.length, AudioTrack.WRITE_BLOCKING);
                written += CHUNK_FRAMES;
            } else {
                int correction = Integer.signum(pendingCorrection);
                stretch(chunk, stretched, CHUNK_FRAMES + correction);
                track.write(stretched, 0, (CHUNK_FRAMES + correction) * FRAME_BYTES, AudioTrack.WRITE_BLOCKING);
                written += CHUNK_FRAMES + correction;
                pendingCorrection -= correction;
                corrections++;
            }

            long now = System.nanoTime();
            if (playStart == 0) {
                if (written < targetFrames) continue;
                // app_process takes about a second to start; that audio is stale by now.
                discard(in, in.available() / FRAME_BYTES);
                track.play();
                playStart = now;
            }
            if (now - lastSample < SAMPLE_NANOS || !track.getTimestamp(timestamp)) continue;
            lastSample = now;

            // Timestamps, unlike getPlaybackHeadPosition, advance smoothly and include the HAL's latency.
            long presented = timestamp.framePosition + (now - timestamp.nanoTime) * RATE / 1_000_000_000L;
            delaySum += written + in.available() / FRAME_BYTES - presented;
            if (++samples < SAMPLES_PER_DECISION) continue;
            long delay = delaySum / samples;
            delaySum = samples = 0;

            if (baseline < 0) {
                if (now - playStart > SETTLE_NANOS) {
                    long stale = in.available() / FRAME_BYTES;
                    discard(in, stale);
                    baseline = delay - stale;
                }
            } else {
                long error = delay - baseline;
                if (error > MAX_BACKLOG_FRAMES) {
                    discard(in, Math.min(error, in.available() / FRAME_BYTES));
                } else if (Math.abs(error) > DEADBAND_FRAMES) {
                    pendingCorrection = error > 0 ? -MAX_CORRECTION_FRAMES : MAX_CORRECTION_FRAMES;
                }
            }
            System.out.println(delay * 1000 / RATE + " " + track.getUnderrunCount() + " " + corrections);
            System.out.flush();
        }
        // AudioTrack's service threads would otherwise keep app_process alive past EOF.
        System.exit(0);
    }

    static void discard(FileInputStream in, long frames) throws IOException {
        byte[] scrap = new byte[4096];
        for (long left = frames * FRAME_BYTES; left > 0; ) {
            int n = in.read(scrap, 0, (int) Math.min(left, scrap.length));
            if (n < 0) return;
            left -= n;
        }
    }

    static boolean readChunk(FileInputStream in, byte[] chunk) throws IOException {
        for (int got = 0; got < chunk.length; ) {
            int n = in.read(chunk, got, chunk.length - got);
            if (n < 0) return false;
            got += n;
        }
        return true;
    }

    /** Spreads a one-frame clock-drift correction across the whole chunk, so it doesn't click. */
    static void stretch(byte[] in, byte[] out, int outFrames) {
        double step = (double) (CHUNK_FRAMES - 1) / (outFrames - 1);
        for (int i = 0; i < outFrames; i++) {
            double position = i * step;
            int frame = Math.min((int) position, CHUNK_FRAMES - 2);
            double fraction = position - frame;
            for (int channel = 0; channel < 2; channel++) {
                int a = sample(in, frame, channel), b = sample(in, frame + 1, channel);
                int mixed = (int) Math.round(a + (b - a) * fraction);
                int at = (i * 2 + channel) * 2;
                out[at] = (byte) mixed;
                out[at + 1] = (byte) (mixed >> 8);
            }
        }
    }

    static int sample(byte[] in, int frame, int channel) {
        int at = (frame * 2 + channel) * 2;
        return (in[at] & 0xFF) | (in[at + 1] << 8);
    }
}
