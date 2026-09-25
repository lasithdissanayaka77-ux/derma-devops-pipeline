"""add patient_id to analysis_report

Revision ID: c27febda1dc0
Revises: e6c2c7ec1f7a
Create Date: 2025-12-18 13:26:31.767922

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c27febda1dc0'
down_revision: Union[str, Sequence[str], None] = 'e6c2c7ec1f7a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Schema already contains patient_id in the baseline migration."""
    pass


def downgrade() -> None:
    """No-op migration."""
    pass
