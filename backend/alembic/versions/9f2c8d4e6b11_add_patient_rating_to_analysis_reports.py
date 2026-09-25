"""Add patient rating to analysis reports

Revision ID: 9f2c8d4e6b11
Revises: 32706033288b
Create Date: 2026-01-20 10:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "9f2c8d4e6b11"
down_revision: Union[str, Sequence[str], None] = "32706033288b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Schema already contains patient rating fields in the baseline migration."""
    pass


def downgrade() -> None:
    """No-op migration."""
    pass
