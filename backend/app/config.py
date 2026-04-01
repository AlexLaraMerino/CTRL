from pathlib import Path

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite:///./ctrl.db"
    secret_key: str = "dev-secret-change-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 480
    ctrl_data_root: Path = Path("/var/datos-ctrl")
    allowed_origins: str = "*"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
