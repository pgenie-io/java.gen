package io.pgenie.artifacts.myspace.musiccatalogue.statements;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Date;
import java.time.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import io.codemine.java.postgresql.codecs.Codec;
import io.pgenie.artifacts.myspace.musiccatalogue.Statement;
import io.pgenie.artifacts.myspace.musiccatalogue.codecs.Jdbc;
import io.pgenie.artifacts.myspace.musiccatalogue.types.*;

/**
 * Type-safe binding for the {@code update_album_recording_returning} query.
 *
 * <h2>SQL Template</h2>
 *
 * <pre>{@code
 * -- Update album recording information
 * update album
 * set recording = $recording
 * where id = $id
 * returning *
 * }</pre>
 *
 * <h2>Source Path</h2> {@code ./queries/update_album_recording_returning.sql}
 *
 * <p>
 * Generated from SQL queries using the
 * <a href="https://pgenie.io">pGenie</a> code generator.
 */
public record UpdateAlbumRecordingReturning(
        /**
         * Maps to {@code $recording} in the template. Nullable.
         */
        Optional<RecordingInfo> recording,
        /**
         * Maps to {@code $id} in the template.
         */
        long id)
        implements Statement<UpdateAlbumRecordingReturning.Output> {

    // -------------------------------------------------------------------------
    // Result type
    // -------------------------------------------------------------------------
    /**
     * Result of the statement parameterised by {@link UpdateAlbumRecordingReturning}.
     */
    public static final class Output extends ArrayList<OutputRow> {
        Output() {}
    }

    /**
     * Row of {@link Output}.
     */
    public record OutputRow(
            /**
             * Maps to the {@code id} result-set column.
             */
            long id,
            /**
             * Maps to the {@code name} result-set column.
             */
            String name,
            /**
             * Maps to the {@code released} result-set column. Nullable.
             */
            Optional<LocalDate> released,
            /**
             * Maps to the {@code format} result-set column. Nullable.
             */
            Optional<AlbumFormat> format,
            /**
             * Maps to the {@code recording} result-set column. Nullable.
             */
            Optional<RecordingInfo> recording,
            /**
             * Maps to the {@code tracks} result-set column. Nullable.
             */
            Optional<List<TrackInfo>> tracks,
            /**
             * Maps to the {@code disc} result-set column. Nullable.
             */
            Optional<DiscInfo> disc) {}

    // -------------------------------------------------------------------------
    // Statement implementation
    // -------------------------------------------------------------------------
    @Override
    public String sql() {
        return """
               -- Update album recording information
               update album
               set recording = ?::public.recording_info
               where id = ?
               returning *
               """;
    }

    @Override
    public void bindParams(PreparedStatement ps) throws SQLException {
        Jdbc.bind(ps, 1, RecordingInfo.CODEC, this.recording().orElse(null));
        ps.setLong(2, this.id());
    }

    @Override
    public boolean returnsRows() {
        return true;
    }

    @Override
    public Output decodeResultSet(ResultSet rs) throws SQLException {
        Output output = new Output();
        while (rs.next()) {
            try {
                long id = rs.getLong(1);
                String name = rs.getString(2);
                Optional<LocalDate> released;
                {
                    Date releasedSql = rs.getDate(3);
                    if (releasedSql != null) {
                        released = Optional.of(releasedSql.toLocalDate());
                    } else {
                        released = Optional.empty();
                    }
                }
                Optional<AlbumFormat> format;
                {
                    String formatStr = rs.getString(4);
                    if (formatStr != null) {
                        format = Optional.of(AlbumFormat.CODEC.decodeInTextFromString(formatStr));
                    } else {
                        format = Optional.empty();
                    }
                }
                Optional<RecordingInfo> recording;
                {
                    String recordingStr = rs.getString(5);
                    if (recordingStr != null) {
                        recording = Optional.of(RecordingInfo.CODEC.decodeInTextFromString(recordingStr));
                    } else {
                        recording = Optional.empty();
                    }
                }
                Optional<List<TrackInfo>> tracks;
                {
                    String tracksStr = rs.getString(6);
                    if (tracksStr != null) {
                        tracks = Optional.of(TrackInfo.CODEC.inDim().decodeInTextFromString(tracksStr));
                    } else {
                        tracks = Optional.empty();
                    }
                }
                Optional<DiscInfo> disc;
                {
                    String discStr = rs.getString(7);
                    if (discStr != null) {
                        disc = Optional.of(DiscInfo.CODEC.decodeInTextFromString(discStr));
                    } else {
                        disc = Optional.empty();
                    }
                }

                output.add(new OutputRow(id, name, released, format, recording, tracks, disc));
            } catch (io.codemine.java.postgresql.codecs.Codec.DecodingException e) {
                throw new IllegalStateException(e);
            }
        }
        return output;
    }

    @Override
    public UpdateAlbumRecordingReturning.Output decodeAffectedRows(long affectedRows) {
        throw new UnsupportedOperationException();
    }
}
