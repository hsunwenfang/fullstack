# syntax=docker/dockerfile:1.6

FROM node:20-alpine AS base
WORKDIR /app

COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./

# Use a single shell RUN to install deps depending on the lockfile present
RUN /bin/sh -lc "\
	if [ -f pnpm-lock.yaml ]; then npm i -g pnpm && pnpm i --frozen-lockfile; \
	elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
	elif [ -f package-lock.json ]; then npm ci; \
	else npm install; fi\
"

COPY . .

EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
