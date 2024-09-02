<p align="center">
  <img src="https://i.imgur.com/2MZbIRh.png" width="240" />
</p>

# SysPatcher
### Bash script tool to automate remote tasks on servers via SSH


## ⚙️ Features

- Full APT update & upgrade
- Upgrade global yarn/npm packages
- Upgrade prometheus node_exporter package
- Apply restartings
  - Nginx
  - Apache2
  - Redis
  - PHP-FPM
  - Grafana server
  - Grafana Loki
  - Prometheus
 
## 📋 Requirements
  - Bash version >= v4 _(to be able to use ```declare -A```)_


## 💳 Examples

- Without server restart `./sys-patcher.sh`
- With server restart: `./sys-patcher.sh --reboot`


## ♻️ License
© Copyright Marc Jorge

The library is distributed under the GNU GPLv3 [LICENSE](https://github.com/mjorgegulab/sys-patcher/blob/main/LICENSE).

