# SSH Config Setup - Connect by Name

## Add to ~/.ssh/config

Add this to your `~/.ssh/config` file:

```ssh-config
# Ido-Esperanto Extractor EC2
Host ido-extractor
    HostName 54.220.110.151
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Alternative short name
Host extractor
    HostName 54.220.110.151
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

## Quick Setup Command

```bash
cat >> ~/.ssh/config << 'EOF'

# Ido-Esperanto Extractor EC2
Host ido-extractor
    HostName 54.220.110.151
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host extractor
    HostName 54.220.110.151
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
```

## Now Connect by Name

```bash
# Use friendly name
ssh ido-extractor

# Or shorter
ssh extractor
```

## Test Connection

```bash
ssh ido-extractor "echo 'Connection successful!'"
```

## Benefits

- ✅ Easy to remember: `ssh ido-extractor`
- ✅ No need to remember IP
- ✅ No need to specify key file
- ✅ Auto-reconnect on network issues
- ✅ Works with scp: `scp file.txt ido-extractor:~/`
