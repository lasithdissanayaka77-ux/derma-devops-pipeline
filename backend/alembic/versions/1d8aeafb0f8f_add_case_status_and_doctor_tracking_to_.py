"""Add case status and doctor tracking to AnalysisReport

Revision ID: 1d8aeafb0f8f
Revises: c27febda1dc0
Create Date: 2025-12-20 13:41:44.924227

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '1d8aeafb0f8f'
down_revision: Union[str, Sequence[str], None] = 'c27febda1dc0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Schema already contains these fields in the baseline migration."""
    pass


def downgrade() -> None:
    """No-op migration."""
    pass
