# Управление секретами в Ansible

Этот проект использует **Ansible Vault** для безопасного хранения паролей, токенов и других конфиденциальных данных.

## Структура vault-файлов

Секреты организованы в следующие файлы:

```
ansible/inventories/
├── group_vars/
│   ├── vault_all.yml                    # Общие секреты для всех хостов
│   ├── vault_k8s_apps_stage.yml         # Секреты для stage-окружения K8s
│   └── vault_k8s_apps_prod.yml          # Секреты для prod-окружения K8s
└── host_vars/
    ├── vault_stage-runner.yml           # Секреты для stage runner
    └── vault_prod-runner.yml            # Секреты для prod runner
```

## Первоначальная настройка

### 1. Создайте файл с паролем для vault

```bash
# Создайте надежный пароль и сохраните его
echo "your-strong-vault-password" > ~/.ansible_vault_password
chmod 600 ~/.ansible_vault_password
```

⚠️ **Важно**: Этот пароль НЕ должен храниться в git. Добавьте его в `.gitignore`.

### 2. Обновите ansible.cfg

Убедитесь, что в [`ansible/ansible.cfg`](ansible/ansible.cfg) указан путь к файлу с паролем:

```ini
[defaults]
vault_password_file = ~/.ansible_vault_password
```

## Работа с vault-файлами

### Заполнение секретов

1. **Отредактируйте незашифрованные файлы** и заполните реальные значения:

```bash
# Редактируйте файлы в текстовом редакторе
vim ansible/inventories/group_vars/vault_all.yml
vim ansible/inventories/group_vars/vault_k8s_apps_stage.yml
vim ansible/inventories/group_vars/vault_k8s_apps_prod.yml
vim ansible/inventories/host_vars/vault_stage-runner.yml
vim ansible/inventories/host_vars/vault_prod-runner.yml
```

### Шифрование vault-файлов

После заполнения секретов **обязательно зашифруйте** их перед коммитом:

```bash
# Зашифровать все vault-файлы
cd ansible/inventories

# Group vars
ansible-vault encrypt group_vars/vault_*.yml

# Host vars
ansible-vault encrypt host_vars/vault_*.yml

# Или все сразу
ansible-vault encrypt group_vars/vault_*.yml host_vars/vault_*.yml
```

### Просмотр зашифрованных файлов

```bash
# Просмотр содержимого
ansible-vault view group_vars/vault_all.yml

# Просмотр нескольких файлов
ansible-vault view group_vars/vault_*.yml
```

### Редактирование зашифрованных файлов

```bash
# Открыть в редакторе (автоматически расшифрует и зашифрует после сохранения)
ansible-vault edit group_vars/vault_all.yml
```

### Расшифровка файлов

```bash
# Расшифровать для редактирования (НЕ КОММИТЬТЕ в git!)
ansible-vault decrypt group_vars/vault_all.yml

# После редактирования снова зашифруйте
ansible-vault encrypt group_vars/vault_all.yml
```

### Смена пароля vault

```bash
# Сменить пароль для всех vault-файлов
ansible-vault rekey group_vars/vault_*.yml host_vars/vault_*.yml
```

## Использование секретов в playbooks

Секреты автоматически подключаются через vault-переменные. Пример:

```yaml
# В defaults/main.yml роли
redis_password: "{{ vault_redis_password | default('CHANGE_ME') }}"

# В vault_k8s_apps_stage.yml (зашифрован)
vault_redis_password: "actual-secure-password-123"
```

Ansible автоматически подставит значение из vault-файла при выполнении playbook.

## Запуск playbooks с vault

Если `vault_password_file` настроен в `ansible.cfg`, просто запускайте playbook:

```bash
ansible-playbook -i inventories/hosts.yml playbooks/k8s-apps-stage.yml
```

Если пароль не настроен в конфиге, используйте флаг `--ask-vault-pass`:

```bash
ansible-playbook -i inventories/hosts.yml playbooks/k8s-apps-stage.yml --ask-vault-pass
```

Или укажите файл с паролем явно:

```bash
ansible-playbook -i inventories/hosts.yml playbooks/k8s-apps-stage.yml \
  --vault-password-file ~/.ansible_vault_password
```

## Список секретов по категориям

### Общие секреты (vault_all.yml)

| Переменная | Описание |
|------------|----------|
| `vault_vpn_admin_password` | Пароль администратора NetBird UI |
| `vault_gitlab_smtp_password` | Пароль SMTP для GitLab |
| `vault_gitlab_backup_s3_access_key` | Access key для S3 бэкапов GitLab |
| `vault_gitlab_backup_s3_secret_key` | Secret key для S3 бэкапов GitLab |

### Stage K8s приложения (vault_k8s_apps_stage.yml)

| Переменная | Описание |
|------------|----------|
| `vault_cnpg_pg_password` | Пароль PostgreSQL (CloudNativePG) |
| `vault_redis_password` | Пароль Redis |
| `vault_temporal_pg_password` | Пароль PostgreSQL для Temporal |
| `vault_vaultwarden_admin_token` | Admin токен для Vaultwarden |

### Production K8s приложения (vault_k8s_apps_prod.yml)

| Переменная | Описание |
|------------|----------|
| `vault_temporal_pg_password` | Пароль PostgreSQL для Temporal |
| `vault_vaultwarden_admin_token` | Admin токен для Vaultwarden |

### GitLab Runners (vault_stage-runner.yml, vault_prod-runner.yml)

| Переменная | Описание |
|------------|----------|
| `vault_gitlab_runner_token` | Токен регистрации GitLab Runner (glrt-...) |

## Генерация надежных паролей

```bash
# Генерация случайного пароля (32 символа)
openssl rand -base64 32

# Генерация буквенно-цифрового пароля (24 символа)
openssl rand -hex 24

# Для Vaultwarden admin token (рекомендуется использовать argon2)
echo -n "your-admin-password" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4
```

## Best Practices

1. ✅ **Всегда шифруйте** vault-файлы перед коммитом в git
2. ✅ **Используйте надежные пароли** для vault и всех секретов
3. ✅ **Разделяйте секреты** по окружениям (stage/prod)
4. ✅ **Регулярно ротируйте** пароли и токены
5. ✅ **Храните vault password** в безопасном месте (password manager)
6. ❌ **Никогда не коммитьте** незашифрованные секреты в git
7. ❌ **Не храните** vault password в репозитории
8. ❌ **Не используйте** одинаковые пароли для разных окружений

## Проверка статуса шифрования

```bash
# Проверить, зашифрован ли файл
head -n 1 group_vars/vault_all.yml

# Если файл зашифрован, вы увидите:
# $ANSIBLE_VAULT;1.1;AES256
# ...

# Если не зашифрован, вы увидите:
# ---
# vault_vpn_admin_password: ...
```

## Troubleshooting

### Ошибка: "Attempting to decrypt but no vault secrets found"

**Причина**: Файлы не зашифрованы, но Ansible ожидает vault-файлы.

**Решение**: Зашифруйте vault-файлы:
```bash
ansible-vault encrypt group_vars/vault_*.yml host_vars/vault_*.yml
```

### Ошибка: "ERROR! Decryption failed"

**Причина**: Неверный пароль vault.

**Решение**: Проверьте пароль в `~/.ansible_vault_password` или используйте правильный пароль.

### Переменная не подставляется

**Причина**: Vault-файл не загружается или переменная называется иначе.

**Решение**: 
1. Убедитесь, что vault-файл называется `vault_*.yml`
2. Проверьте имя переменной в vault-файле
3. Используйте `-vvv` для отладки:
```bash
ansible-playbook -i inventories/hosts.yml playbooks/k8s-apps-stage.yml -vvv
```

## Альтернативные подходы (не используются в проекте)

Проект также частично поддерживает переменные окружения через конструкции типа:
```yaml
redis_password: "{{ vault_redis_password | default(lookup('env', 'REDIS_PASSWORD')) }}"
```

Это позволяет передавать секреты через environment variables в CI/CD, но **рекомендуется использовать Ansible Vault** для локального развертывания.
