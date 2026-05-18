FROM alpine:3.20

ARG KUBECTL_VERSION=v1.32.3
ARG HELM_VERSION=v3.17.3
ARG BW_CLI_VERSION=2024.2.1

RUN apk add --no-cache curl jq bash npm openssl git ca-certificates

# kubectl (pinned)
RUN curl -sLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl

# helm (pinned, direct tarball — no install script)
RUN curl -sLo /tmp/helm.tar.gz \
      "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
    && tar -xzf /tmp/helm.tar.gz -C /usr/local/bin \
         --strip-components=1 linux-amd64/helm \
    && rm /tmp/helm.tar.gz

# Bitwarden CLI (pinned — newer versions have bugs with self-hosted Vaultwarden)
RUN npm install -g @bitwarden/cli@${BW_CLI_VERSION} --quiet 2>/dev/null

CMD ["/bin/bash"]
