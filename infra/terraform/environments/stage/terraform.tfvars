# ──────────────────────────────────────────────────────────────────────────────
# Stage Environment – Variable Values
# ──────────────────────────────────────────────────────────────────────────────
# Sensitive values (yc_token, passwords) should be set via:
#   - Environment variables: TF_VAR_yc_token, TF_VAR_pg_password, TF_VAR_runner_registration_token, etc.
#   - Or a separate .auto.tfvars file NOT committed to git
# ──────────────────────────────────────────────────────────────────────────────

yc_cloud_id  = "<YOUR_YC_CLOUD_ID>"
yc_folder_id = "<YOUR_YC_FOLDER_ID>"

ssh_public_keys = [
  "ssh-ed25519 <YOUR_SSH_ED25519_PUBLIC_KEY>",
]
ubuntu_image_id = "<UBUNTU_22_04_LTS_IMAGE_ID>" # Ubuntu 22.04 LTS

vpn_cidrs           = ["100.64.0.0/10"]
gitlab_external_url = "https://gitlab.myapp.example.com"
