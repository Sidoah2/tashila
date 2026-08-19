import os

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )

    port: int = 8000
    environment: str = "development"
    mongo_uri: str
    mongo_db_name: str = "tashila"
    redis_url: str
    jwt_secret: str
    jwt_refresh_secret: str
    jwt_expire_minutes: int = 60
    jwt_refresh_expire_days: int = 30
    admin_jwt_secret: str
    admin_jwt_expire_minutes: int = 480
    fcm_server_key: str = ""
    traccar_sms_url: str = "https://www.traccar.org/sms/"
    traccar_sms_token: str = ""
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_phone_number: str = ""
    smssak_api_key: str = ""
    smssak_project_id: str = ""
    smssak_country: str = "dz"
    simulation_otp_secret: str = ""
    allowed_origins: str = "*"
    upload_dir: str = "/tmp/tashila_uploads"
    cloudinary_url: str = ""
    test_otp_enabled: bool = True
    test_otp_code: str = "111111"
    max_otp_attempts: int = 5
    otp_window_seconds: int = 600
    firebase_credentials_path: str = "firebase-adminsdk.json"

    offer_ttl_seconds: int = 180
    max_dispatch_candidates: int = 5
    # Short retry when geo query returns nobody (driver may come online momentarily).
    dispatch_no_candidate_grace_seconds: int = 8
    dispatch_retry_interval_seconds: int = 2
    reject_ttl_seconds: int = 3600
    dispatch_lock_ttl_seconds: int = 600

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()]


settings = Settings()
os.makedirs(settings.upload_dir, exist_ok=True)
