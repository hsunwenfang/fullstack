up:
	docker compose up --build

down:
	docker compose down -v

fmt:
	black backend || true
