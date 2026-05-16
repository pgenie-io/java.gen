package io.pgenie.artifacts.myspace.musiccatalogue.types;

import static org.junit.jupiter.api.Assertions.*;

import io.pgenie.artifacts.myspace.musiccatalogue.AbstractDatabaseIT;
import io.codemine.java.postgresql.jdbc.Statement;
import java.sql.*;
import java.time.*;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class RecordingInfoIT extends AbstractDatabaseIT {

    private Optional<RecordingInfo> roundtrip(RecordingInfo input) throws SQLException {
        return execute(new Statement<Optional<RecordingInfo>>() {
            @Override public String sql() { return "select ?::recording_info"; }
            @Override public void bindParams(PreparedStatement ps) throws SQLException {
                RecordingInfo.CODEC.bind(ps, 1, input);
            }
            @Override public boolean returnsRows() { return true; }
            @Override public Optional<RecordingInfo> decodeResultSet(ResultSet rs) throws SQLException {
                rs.next();
                return RecordingInfo.CODEC.decodeOptional(rs, 0, 1);
            }
            @Override public Optional<RecordingInfo> decodeAffectedRows(long r) {
                throw new UnsupportedOperationException();
            }
        });
    }

    @Test
    void roundtripNull() throws SQLException {
        assertEquals(Optional.empty(), roundtrip(null));
    }

    @Test
    void roundtripCombination0() throws SQLException {
        var value = new RecordingInfo(Optional.empty(), Optional.empty(), Optional.empty(), Optional.empty());
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination1() throws SQLException {
        var value = new RecordingInfo(Optional.of(""), Optional.empty(), Optional.empty(), Optional.empty());
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination2() throws SQLException {
        var value = new RecordingInfo(Optional.empty(), Optional.of(""), Optional.empty(), Optional.empty());
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination3() throws SQLException {
        var value = new RecordingInfo(Optional.of(""), Optional.of(""), Optional.empty(), Optional.empty());
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination4() throws SQLException {
        var value = new RecordingInfo(Optional.empty(), Optional.empty(), Optional.of(""), Optional.empty());
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination5() throws SQLException {
        var value = new RecordingInfo(Optional.of(""), Optional.empty(), Optional.of(""), Optional.empty());
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination6() throws SQLException {
        var value = new RecordingInfo(Optional.empty(), Optional.of(""), Optional.of(""), Optional.empty());
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination7() throws SQLException {
        var value = new RecordingInfo(Optional.of(""), Optional.of(""), Optional.of(""), Optional.empty());
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination8() throws SQLException {
        var value = new RecordingInfo(Optional.empty(), Optional.empty(), Optional.empty(), Optional.of(LocalDate.of(2000, 1, 1)));
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination9() throws SQLException {
        var value = new RecordingInfo(Optional.of(""), Optional.empty(), Optional.empty(), Optional.of(LocalDate.of(2000, 1, 1)));
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination10() throws SQLException {
        var value = new RecordingInfo(Optional.empty(), Optional.of(""), Optional.empty(), Optional.of(LocalDate.of(2000, 1, 1)));
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination11() throws SQLException {
        var value = new RecordingInfo(Optional.of(""), Optional.of(""), Optional.empty(), Optional.of(LocalDate.of(2000, 1, 1)));
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination12() throws SQLException {
        var value = new RecordingInfo(Optional.empty(), Optional.empty(), Optional.of(""), Optional.of(LocalDate.of(2000, 1, 1)));
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination13() throws SQLException {
        var value = new RecordingInfo(Optional.of(""), Optional.empty(), Optional.of(""), Optional.of(LocalDate.of(2000, 1, 1)));
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination14() throws SQLException {
        var value = new RecordingInfo(Optional.empty(), Optional.of(""), Optional.of(""), Optional.of(LocalDate.of(2000, 1, 1)));
        assertEquals(Optional.of(value), roundtrip(value));
    }

    @Test
    void roundtripCombination15() throws SQLException {
        var value = new RecordingInfo(Optional.of(""), Optional.of(""), Optional.of(""), Optional.of(LocalDate.of(2000, 1, 1)));
        assertEquals(Optional.of(value), roundtrip(value));
    }
}
