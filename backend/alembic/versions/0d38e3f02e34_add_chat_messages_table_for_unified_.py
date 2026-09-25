"""Add chat messages table for unified history

Revision ID: 0d38e3f02e34
Revises: 1d8aeafb0f8f
Create Date: 2025-12-20 14:23:12.951926

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '0d38e3f02e34'
down_revision: Union[str, Sequence[str], None] = '1d8aeafb0f8f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Schema already contains chat_messages in the baseline migration."""
    pass


def downgrade() -> None:
    """No-op migration."""
    pass
