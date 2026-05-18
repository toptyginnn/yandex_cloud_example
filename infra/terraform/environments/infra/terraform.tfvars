# ──────────────────────────────────────────────────────────────────────────────
# Infra Environment – Variable Values
# ──────────────────────────────────────────────────────────────────────────────
# Sensitive values should be set via:
#   - Environment variables: TF_VAR_yc_token, etc.
#   - Or a separate .auto.tfvars file NOT committed to git
# ──────────────────────────────────────────────────────────────────────────────

yc_cloud_id  = "<YOUR_YC_CLOUD_ID>"
yc_folder_id = "<YOUR_YC_FOLDER_ID>"

ssh_public_keys = [
  "ssh-ed25519 <YOUR_SSH_ED25519_PUBLIC_KEY>",
]
ubuntu_image_id = "<UBUNTU_22_04_LTS_IMAGE_ID>" # Ubuntu 22.04 LTS

gitlab_external_url                         = "https://gitlab.myapp.example.com"
gitlab_instance_cores                       = 4
gitlab_instance_memory_gb                   = 8
gitlab_boot_disk_size_gb                    = 50
gitlab_data_disk_size_gb                    = 100
mailcow_instance_cores     = 2
mailcow_instance_memory_gb = 8
mailcow_boot_disk_size_gb  = 30
mailcow_data_disk_size_gb  = 50

gitlab_backup_bt6_bucket_enabled            = true
gitlab_backup_bt6_bucket_name               = "infra-gitlab-backups-<YOUR_YC_FOLDER_ID>"
gitlab_backup_bt6_bucket_versioning_enabled = false


