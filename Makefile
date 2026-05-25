SCRIPTS := $(CURDIR)/scripts

.PHONY: help start stop update os-update backup status report monitor check-updates firewall install logs

help:
	@echo "Homelab management"
	@echo ""
	@echo "  make start          Start all services"
	@echo "  make stop           Stop all services"
	@echo "  make status         Show running containers"
	@echo "  make update         Pull and restart Docker services"
	@echo "  make os-update      Refresh apt package list"
	@echo "  make backup         Run manual backup"
	@echo "  make report         Send RPi report to Telegram"
	@echo "  make monitor        Run health/disk/temp alert check"
	@echo "  make check-updates  Check for new image versions"
	@echo "  make firewall       Apply firewall rules (sudo)"
	@echo "  make install        Install cron jobs + logrotate"
	@echo "  make logs           Tail update log"

start:
	bash $(SCRIPTS)/start-all.sh

stop:
	bash $(SCRIPTS)/stop-all.sh

status:
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

update:
	bash $(SCRIPTS)/update.sh

os-update:
	bash $(SCRIPTS)/os-update.sh

backup:
	bash $(SCRIPTS)/backup.sh

report:
	bash $(SCRIPTS)/rpi-report.sh

monitor:
	bash $(SCRIPTS)/monitor.sh

check-updates:
	bash $(SCRIPTS)/check-updates.sh

firewall:
	sudo bash $(SCRIPTS)/setup-firewall.sh

install:
	bash $(SCRIPTS)/install-cron.sh

logs:
	tail -100 $(CURDIR)/logs/update.log
