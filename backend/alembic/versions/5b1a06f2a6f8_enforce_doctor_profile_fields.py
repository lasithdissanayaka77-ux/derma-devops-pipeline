"""Enforce doctor profile required fields and add avatar.

Revision ID: 5b1a06f2a6f8
Revises: 0d38e3f02e34
Create Date: 2025-12-21 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5b1a06f2a6f8'
down_revision: Union[str, Sequence[str], None] = '0d38e3f02e34'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Schema already contains doctor profile fields in the baseline migration."""
    pass


def downgrade() -> None:
    """No-op migration."""
    pass
