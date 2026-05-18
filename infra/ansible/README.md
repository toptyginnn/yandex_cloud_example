# Ansible Infrastructure Management

Этот каталог содержит Ansible playbooks и роли для автоматизации развертывания инфраструктуры проекта bt6.

## 📋 Содержание

- [Быстрый старт](#быстрый-старт)
- [Структура проекта](#структура-проекта)
- [Управление секретами](#управление-секретами)
- [Playbooks](#playbooks)
- [Роли](#роли)

## 🚀 Быстрый старт

### 1. Установка зависимостей

```bash
# Установите Ansible
pip install ansible

# Или через apt (Ubuntu/Debian)
sudo apt update
sudo apt install ansible
```

### 2. Настройка секретов

```bash
cd ansible
./ansible-vault-setup.sh
```

Подробнее: [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md)

### 3. Создание inventory файла

```bash
# Скопируйте пример и отредактируйте
cp inventories/hosts.yml.example inventories/hosts.yml
vim inventories/hosts.yml
```

### 4. Запуск playbook

```bash
# Пример: установка GitLab Runner для stage
ansible-playbook -i inventories/hosts.yml playbooks/gitlab-runner-stage.yml

# Пример: развертывание K8s приложений в stage
ansible-playbook -i inventories/hosts.yml playbooks/k8s-apps-stage.yml
```

## 📁 Структура проекта

```
ansible/
├── ansible.cfg                  # Конфигурация Ansible
├── README.md                    # Этот файл
├── SECRETS_MANAGEMENT.md        # Документация по управлению секретами
├── .ansible-vault-setup.sh      # Скрипт настройки Ansible Vault
│
├── inventories/                 # Инвентори файлы
│   ├── hosts.yml.example        # Пример инвентори
│   ├── hosts.yml                # Актуальный инвентори (не в git)
│   ├── group_vars/              # Переменные для групп хостов
│   │   ├── all.yml              # Общие переменные
│   │   ├── vault_all.yml        # Зашифрованные секреты (общие)
│   │   ├── k8s_apps_stage.yml   # Переменные для stage K8s
│   │   ├── k8s_apps_prod.yml    # Переменные для prod K8s
│   │   ├── vault_k8s_apps_stage.yml  # Секреты stage
│   │   └── vault_k8s_apps_prod.yml   # Секреты prod
│   └── host_vars/               # Переменные для конкретных хостов
│       ├── stage-runner.yml
│       ├── prod-runner.yml
│       ├── vault_stage-runner.yml    # Секреты stage runner
│       └── vault_prod-runner.yml     # Секреты prod runner
│
├── playbooks/                   # Ansible playbooks
│   ├── vpn.yml                  # Развертывание VPN (WireGuard)
│   ├── gitlab-server.yml        # Развертывание GitLab Server
│   ├── gitlab-runner-stage.yml  # Stage GitLab Runner
│   ├── gitlab-runner-prod.yml   # Production GitLab Runner
│   ├── k8s-apps-stage.yml       # Stage K8s приложения
│   └── k8s-apps-prod.yml        # Production K8s приложения
│
└── roles/                       # Ansible роли
    ├── docker_host/             # Установка Docker
    ├── vpn/                     # WireGuard VPN
    ├── gitlab_server/           # GitLab CE Server
    ├── gitlab_runner/           # GitLab Runner
    ├── cloudnative_pg/          # CloudNativePG (PostgreSQL operator)
    ├── redis_k8s/               # Redis в K8s
    ├── temporal/                # Temporal workflow engine
    └── vaultwarden/             # Vaultwarden (password manager)
```

## 🔐 Управление секретами

Проект использует **Ansible Vault** для безопасного хранения паролей и токенов.

### Основные команды

```bash
# Настройка vault (первый раз)
./ansible-vault-setup.sh

# Редактирование секретов
ansible-vault edit inventories/group_vars/vault_all.yml

# Просмотр секретов
ansible-vault view inventories/group_vars/vault_all.yml

# Шифрование незашифрованных файлов
ansible-vault encrypt inventories/group_vars/vault_*.yml
```

**📖 Полная документация**: [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md)

## 📚 Playbooks

### Инфраструктурные сервисы

#### VPN (WireGuard)
```bash
ansible-playbook -i inventories/hosts.yml playbooks/vpn.yml
```
Устанавливает WireGuard VPN с веб-интерфейсом wg-easy и Caddy в качестве reverse proxy.

#### GitLab Server
```bash
ansible-playbook -i inventories/hosts.yml playbooks/gitlab-server.yml
```
Разворачивает GitLab CE с Caddy для HTTPS.

#### GitLab Runners
```bash
# Stage runner
ansible-playbook -i inventories/hosts.yml playbooks/gitlab-runner-stage.yml

# Production runner
ansible-playbook -i inventories/hosts.yml playbooks/gitlab-runner-prod.yml
```
Регистрирует и настраивает GitLab Runner для CI/CD.

### K8s приложения

#### Stage окружение
```bash
ansible-playbook -i inventories/hosts.yml playbooks/k8s-apps-stage.yml
```
Разворачивает:
- CloudNativePG (PostgreSQL operator)
- Redis
- Temporal
- Vaultwarden

#### Production окружение
```bash
ansible-playbook -i inventories/hosts.yml playbooks/k8s-apps-prod.yml
```
Разворачивает production-версии приложений.

## 🔧 Роли

### docker_host
Устанавливает Docker Engine и Docker Compose на целевой хост.

**Используется в**: VPN, GitLab Server, GitLab Runners

### vpn
Разворачивает WireGuard VPN с веб-интерфейсом [wg-easy](https://github.com/wg-easy/wg-easy) и Caddy.

**Переменные**:
- `vpn_public_host` - публичный домен VPN
- `vpn_admin_password` - пароль администратора UI
- `vpn_wireguard_port` - порт WireGuard (по умолчанию 51820)

### gitlab_server
Разворачивает GitLab Community Edition с Caddy для автоматического HTTPS.

**Переменные**:
- `gitlab_external_url` - внешний URL GitLab
- `gitlab_smtp_password` - пароль SMTP (опционально)

### gitlab_runner
Регистрирует и запускает GitLab Runner в Docker.

**Переменные**:
- `gitlab_runner_token` - токен регистрации (из vault)
- `gitlab_runner_tags` - теги runner'а
- `gitlab_runner_name` - имя runner'а

### cloudnative_pg
Устанавливает [CloudNativePG operator](https://cloudnative-pg.io/) и создает PostgreSQL кластер в K8s.

**Переменные**:
- `cnpg_pg_password` - пароль PostgreSQL (из vault)
- `cnpg_pg_database` - имя БД

### redis_k8s
Устанавливает Redis в K8s через Bitnami Helm chart.

**Переменные**:
- `redis_password` - пароль Redis (из vault)

### temporal
Разворачивает [Temporal](https://temporal.io/) workflow engine в K8s.

**Переменные**:
- `temporal_external_pg_password` - пароль PostgreSQL (из vault)

### vaultwarden
Устанавливает [Vaultwarden](https://github.com/dani-garcia/vaultwarden) (Bitwarden-compatible password manager) в K8s.

**Переменные**:
- `vaultwarden_admin_token` - admin token (из vault)
- `vaultwarden_domain` - домен для доступа

## 🐛 Troubleshooting

### Ошибка подключения к хостам

```bash
# Проверьте SSH доступ
ssh ubuntu@<host-ip>

# Проверьте инвентори файл
ansible-inventory -i inventories/hosts.yml --list
```

### Ошибки с vault

```bash
# Проверьте статус шифрования
head -n 1 inventories/group_vars/vault_all.yml

# Проверьте пароль vault
cat ~/.ansible_vault_password
```

### Отладка playbook

```bash
# Добавьте флаг -vvv для детальной отладки
ansible-playbook -i inventories/hosts.yml playbooks/k8s-apps-stage.yml -vvv

# Проверьте только определенный хост
ansible-playbook -i inventories/hosts.yml playbooks/k8s-apps-stage.yml --limit stage-k8s
```

## 📖 Дополнительная документация

- [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md) - Управление секретами через Ansible Vault
- [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) - Общее руководство по развертыванию
- [DEPLOYMENT_ORDER.md](../DEPLOYMENT_ORDER.md) - Порядок развертывания компонентов

## 🤝 Contributing

При добавлении новых секретов:
1. Добавьте переменную с префиксом `vault_` в соответствующий vault-файл
2. Используйте её с fallback: `"{{ vault_variable | default('CHANGE_ME') }}"`
3. Зашифруйте vault-файл перед коммитом: `ansible-vault encrypt <файл>`

## 📝 License

Проект bt6 - внутренний проект компании.
