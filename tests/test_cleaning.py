import io
import pandas as pd
import pytest
from app.cleaning import clean_csv


def test_missing_and_duplicates():
    raw = b'name,age,score\nAna,20,10\nAna,20,10\nBen,,30\nCal,40,\n'
    output, info = clean_csv(raw)
    result = pd.read_csv(io.BytesIO(output))
    assert len(result) == 3
    assert result.isna().sum().sum() == 0
    assert info['duplicates_removed'] == 1
    assert info['missing_cells_before'] == 2
    assert info['quality_score_after'] == 100.0


def test_all_missing_numeric_and_categorical():
    raw = b'name,age\nA,\n,\nC,\n'
    out, report = clean_csv(raw)
    assert pd.read_csv(io.BytesIO(out)).isna().sum().sum() == 0
    assert report['missing_cells_after'] == 0


def test_empty_rejected():
    with pytest.raises(ValueError):
        clean_csv(b'')


def test_oversize_rejected():
    with pytest.raises(ValueError):
        clean_csv(b'x' * (5 * 1024 * 1024 + 1))


def test_spreadsheet_formula_escaped_in_export():
    raw = b"name,age\n=1+2,20\nnormal,30\n"
    out, report = clean_csv(raw)
    assert b"'=1+2" in out
    assert report['spreadsheet_formula_cells_escaped'] == 1
