-- Create a view combining relevant information
CREATE VIEW version_info_view AS
SELECT
  av.app_id,
  COALESCE(do.device_id, NULL) AS device_id,
  av.id AS version_id,
  av.name AS version_name,
  av.checksum,
  av.session_key,
  av.bucket_id,
  av.storage_provider,
  av.external_url,
  av.r2_path,
  av."minUpdateVersion" AS min_update_version,
  ch.id AS channel_id,
  ch.name AS channel_name,
  ch.allow_dev,
  ch.allow_emulator,
  ch."disableAutoUpdateUnderNative" AS disable_auto_update_under_native,
  ch."disableAutoUpdate" AS disable_auto_update,
  ch.ios,
  ch.android,
  ch."secondaryVersionPercentage" AS secondary_version_percentage,
  ch.enable_progressive_deploy,
  ch."enableAbTesting" AS enable_ab_testing,
  ch.allow_device_self_set,
  ch.public
FROM app_versions av
LEFT JOIN devices_override do ON av.id = do.version
LEFT JOIN channels ch ON av.app_id = ch.app_id AND av.id = ch.version;

-- Create a materialized view based on the view
CREATE MATERIALIZED VIEW version_info AS
SELECT * FROM version_info_view;

-- Create unique index on the materialized view
CREATE UNIQUE INDEX unique_app_device_version_idx ON version_info (app_id, device_id, version_id, channel_id);

-- Create other indexes on the materialized view
CREATE INDEX idx_version_info_app_id ON version_info (app_id);
CREATE INDEX idx_version_info_device_id ON version_info (device_id);
CREATE INDEX idx_version_info_public ON version_info (public);
CREATE INDEX idx_version_info_ios ON version_info (ios);
CREATE INDEX idx_version_info_android ON version_info (android);
