import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine


class DfLoader:
    def __init__(self):
        self.project_root = Path(__file__).resolve().parents[2]
        if not (self.project_root / ".env").exists():
            raise FileNotFoundError(
                f"No .env in {self.project_root}. Open the folder as workspace root, or set "
                "ROOT = Path(r'C:\\Users\\shober\\Projects\\data_scientist_portfolio') "
                "before running this cell."
            )
        load_dotenv(self.project_root / ".env")
        self.engine = create_engine(
            "postgresql+psycopg2://{user}:{password}@{host}:{port}/{dbname}".format(
                user=os.environ["DB_USER"],
                password=os.environ["DB_PASSWORD"],
                host=os.environ["DB_HOST"],
                port=os.environ["DB_PORT"],
                dbname=os.environ["DB_NAME"],
            )
        )
