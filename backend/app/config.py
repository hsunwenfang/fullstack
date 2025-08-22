from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")
    # FastAPI
    app_name: str = Field(default="Fullstack AI App")
    debug: bool = Field(default=False)

    # Database URLs
    # Default to SQLite for easy local runs; Docker overrides via .env
    database_url: str = Field(default="sqlite:///./app.db", alias="DATABASE_URL")
    mongo_url: str = Field(default="mongodb://localhost:27017", alias="MONGO_URL")
    mongo_db: str = Field(default="appdb", alias="MONGO_DB")

    # GenAI provider (OpenAI-compatible)
    openai_api_key: str | None = Field(default=None, alias="OPENAI_API_KEY")
    openai_base_url: str | None = Field(default=None, alias="OPENAI_BASE_URL")
    openai_model: str = Field(default="gpt-4o-mini", alias="OPENAI_MODEL")

    # Azure OpenAI (preferred when provided)
    azure_openai_endpoint: str | None = Field(default=None, alias="AZURE_OPENAI_ENDPOINT")
    azure_openai_api_key: str | None = Field(default=None, alias="AZURE_OPENAI_API_KEY")
    azure_openai_deployment: str | None = Field(default=None, alias="AZURE_OPENAI_DEPLOYMENT")
    azure_openai_api_version: str = Field(default="2024-07-01-preview", alias="AZURE_OPENAI_API_VERSION")

settings = Settings()  # type: ignore
