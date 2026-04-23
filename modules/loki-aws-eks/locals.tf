locals {
  effective_region        = coalesce(var.aws_region, data.aws_region.current.name)
  ruler_bucket_name       = coalesce(try(var.storage.ruler_bucket_name, null), var.storage.bucket_name)
  create_bucket           = try(var.storage.create_bucket, false)
  create_credentials      = try(var.s3_auth.create_credentials, false)
  create_secondary_bucket = local.ruler_bucket_name != var.storage.bucket_name
  created_iam_user_name   = try(var.s3_auth.created.iam_user_name, "loki-s3")
  created_iam_policy_name = try(var.s3_auth.created.iam_policy_name, "loki-s3")
  access_key_id           = local.create_credentials ? aws_iam_access_key.loki[0].id : var.s3_auth.existing.access_key_id
  secret_access_key       = local.create_credentials ? aws_iam_access_key.loki[0].secret : var.s3_auth.existing.secret_access_key
  common_tags             = merge(var.tags, try(var.storage.tags, {}))

  generated_values = {
    loki = {
      image = {
        tag = var.loki.image_tag
      }
      schemaConfig = {
        configs = [
          {
            from         = var.loki.schema_from
            store        = "tsdb"
            object_store = "s3"
            schema       = "v13"
            index = {
              prefix = "loki_index_"
              period = "24h"
            }
          }
        ]
      }
      storage_config = {
        aws = {
          region            = local.effective_region
          bucketnames       = var.storage.bucket_name
          access_key_id     = local.access_key_id
          secret_access_key = local.secret_access_key
          s3forcepathstyle  = var.loki.force_path_style
        }
      }
      ingester = {
        chunk_encoding = "snappy"
      }
      pattern_ingester = {
        enabled = true
      }
      limits_config = {
        allow_structured_metadata = true
        discover_service_name     = ["service"]
        volume_enabled            = true
        retention_period          = var.loki.retention_period
      }
      compactor = {
        retention_enabled    = true
        delete_request_store = "s3"
      }
      ruler = {
        enable_api = true
        storage = {
          type = "s3"
          s3 = {
            region            = local.effective_region
            bucketnames       = local.ruler_bucket_name
            access_key_id     = local.access_key_id
            secret_access_key = local.secret_access_key
            s3forcepathstyle  = var.loki.force_path_style
          }
        }
      }
      querier = {
        max_concurrent = 4
      }
      storage = {
        type = "s3"
        bucketNames = {
          chunks = var.storage.bucket_name
          ruler  = local.ruler_bucket_name
        }
        s3 = {
          region           = local.effective_region
          accessKeyId      = local.access_key_id
          secretAccessKey  = local.secret_access_key
          s3ForcePathStyle = var.loki.force_path_style
        }
      }
    }

    serviceAccount = {
      create = true
      name   = var.service_account_name
    }

    deploymentMode = var.loki.deployment_mode

    ingester = {
      replicas = var.replicas.ingester
      zoneAwareReplication = {
        enabled = false
      }
    }

    querier = {
      replicas       = var.replicas.querier
      maxUnavailable = 2
    }

    queryFrontend = {
      replicas       = var.replicas.query_frontend
      maxUnavailable = 1
    }

    queryScheduler = {
      replicas = var.replicas.query_scheduler
    }

    distributor = {
      replicas       = var.replicas.distributor
      maxUnavailable = 2
    }

    compactor = {
      replicas = var.replicas.compactor
    }

    indexGateway = {
      replicas       = var.replicas.index_gateway
      maxUnavailable = 1
    }

    ruler = {
      replicas       = var.replicas.ruler
      maxUnavailable = 1
    }

    gateway = {
      service = {
        type = var.loki.gateway_service_type
      }
    }

    minio = {
      enabled = false
    }

    backend = {
      replicas = 0
    }

    read = {
      replicas = 0
    }

    write = {
      replicas = 0
    }

    singleBinary = {
      replicas = 0
    }
  }
}
