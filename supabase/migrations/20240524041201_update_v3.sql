create TYPE "public"."update_data" AS (
  -- channel start
	"public" boolean,
  "disableAutoUpdateUnderNative" boolean,
  "enableAbTesting" boolean,
  "enable_progressive_deploy" boolean,
  "secondaryVersionPercentage" boolean,
  "ios" boolean,
  "android" boolean,
  "allow_device_self_set" boolean,
  "allow_emulator" boolean,
  "allow_dev" boolean,
  "disableAutoUpdate" "public"."disable_update",
  -- org start
  "owner_org" "uuid",
  "created_by" "uuid"
);


CREATE TYPE "public"."update_response" AS (
	"ok" BOOLEAN,
	"status" "text",
	"data" "public"."update_data"
);

CREATE TYPE "public"."update_org_info" AS (
	"id" "uuid",
	"created_by" "uuid"
);

CREATE OR REPLACE FUNCTION "public"."update_rpc"(
    "device_id" "uuid", 
    "app_id" "text",
    "default_channel" "text"
) RETURNS "update_response"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
Declare  
 org_info "public"."update_org_info";
 response "public"."update_response";
 channel_devices_row record;
Begin
  SELECT orgs.id, orgs.created_by
  FROM apps
  INNER JOIN orgs on orgs.id=apps.owner_org
  WHERE apps.app_id="update_rpc"."app_id"
  limit 1
  into org_info;

  IF org_info IS NULL THEN
    SELECT false AS "ok", 'app not found' AS "status", NULL AS "data" INTO response;
    return response;
  END IF;

  SELECT * FROM channel_devices
  INNER JOIN channels on channels.id=channel_devices.channel_id
  WHERE channel_devices.device_id="update_rpc"."device_id"::text
  limit 1
  into channel_devices_row;

  RAISE NOTICE '% %', channel_devices_row.channel_id, (channel_devices_row.channel_id IS NOT DISTINCT FROM NULL);
  if channel_devices_row IS DISTINCT FROM NULL THEN
    SELECT 
    true AS "ok", 
    '' AS "status", 
    (SELECT (
        "channel_devices_row"."public",
        "channel_devices_row"."disableAutoUpdateUnderNative",
        "channel_devices_row"."enableAbTesting",
        "channel_devices_row"."enable_progressive_deploy",
        "channel_devices_row"."secondaryVersionPercentage",
        "channel_devices_row"."ios",
        "channel_devices_row"."android",
        "channel_devices_row"."allow_device_self_set",
        "channel_devices_row"."allow_emulator",
        "channel_devices_row"."allow_dev",
        "channel_devices_row"."disableAutoUpdate",
        "org_info"."created_by",
        (select "org_info"."id" as "owner_org")
    )) as "data"
    INTO response;
    return response;
  END IF;


  RAISE EXCEPTION 'TODO %, %', org_info, (channel_devices_row.channel_id IS NOT DISTINCT FROM NULL);
End;  
$$;