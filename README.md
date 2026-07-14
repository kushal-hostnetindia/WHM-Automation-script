# 🚀 WHM Automation Script

A Bash automation script to simplify and automate the initial setup of a WHM/cPanel server. This script reduces manual effort by configuring the server with the required components in just a few steps.

---

## Features

- Configure WHM server automatically
- Install cPanel
- Apply GetLic or V2 license
- Install Node Exporter (Optional)
- Configure hostname
- Reduce manual server setup time

---

## Prerequisites

Before running the script, ensure the following:

- A fresh Linux server
- Root SSH access
- A valid hostname configured
- DNS record created for the hostname
- License (GetLic, V2, or Original)

---

## Quick Installation

Download the script:

```bash
wget https://raw.githubusercontent.com/kushal-hostnetindia/WHM-Automation-script/main/auto.sh
```

Make it executable:

```bash
chmod +x auto.sh
```

Run the script:

```bash
./auto.sh
```

---

## Script Workflow

The script will prompt you to enter the following information:

- Your Name
- Client Name
- Hostname
- cPanel Version
- License Source
- Install Node Exporter (Yes/No)

---

## Hostname Format

The hostname **must** match the DNS record created on your DNS server.

Example:

```
<client-name><last-IP-digit>.dnshostserver.in
```

Example:

```
Pinnacle80.dnshostserver.in
```

---

## Supported cPanel Versions

- 11.126
- 11.130
- 11.132
- 11.134
- 11.136
- release (Latest Stable)

---

## License Options

| Option | Description |
|---------|-------------|
| 1 | V2 License |
| 2 | GetLic |
| 3 | Skip License Installation |

> If an original cPanel license is required, skip the license installation step and apply the original license manually.

---

## Troubleshooting

If the script fails because the **screen** package cannot be installed or DNS resolution fails, run:

```bash
cat >> /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
```

Then rerun the script.

---

## Documentation

Detailed execution guide:

**WHM-Automation-Script-Execution-Guide.pdf**

---

## Author

**Kushal Jangid**

---

## License

This project is intended for internal automation and server deployment.
