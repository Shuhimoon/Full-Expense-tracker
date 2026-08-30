package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"fulljizhang/internal/app"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://fulljizhang:fulljizhang@127.0.0.1:5432/fulljizhang?sslmode=disable"
	}
	listen := os.Getenv("LISTEN_ADDR")
	if listen == "" {
		listen = ":8080"
	}

	waitForDB(dsn)
	runMigrations(dsn)

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		log.Fatalf("pgxpool: %v", err)
	}
	defer pool.Close()

	a := app.New(pool)
	srv := &http.Server{
		Addr:              listen,
		Handler:           a.Router(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("listening on %s", listen)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}

func waitForDB(dsn string) {
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		log.Fatalf("parse dsn: %v", err)
	}
	addr := net.JoinHostPort(cfg.ConnConfig.Host, fmt.Sprintf("%d", cfg.ConnConfig.Port))
	deadline := time.Now().Add(90 * time.Second)
	for {
		c, err := net.DialTimeout("tcp", addr, 5*time.Second)
		if err == nil {
			_ = c.Close()
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			pool, perr := pgxpool.NewWithConfig(ctx, cfg)
			if perr == nil {
				perr = pool.Ping(ctx)
				pool.Close()
			}
			cancel()
			if perr == nil {
				return
			}
			err = perr
		}
		if time.Now().After(deadline) {
			log.Fatalf("postgres not ready at %s: %v", addr, err)
		}
		log.Printf("waiting for postgres at %s: %v", addr, err)
		time.Sleep(1 * time.Second)
	}
}

func runMigrations(dsn string) {
	path := os.Getenv("MIGRATIONS_PATH")
	if path == "" {
		for _, c := range []string{"/migrations", "migrations", "../migrations"} {
			if st, err := os.Stat(c); err == nil && st.IsDir() {
				path = c
				break
			}
		}
	}
	if path == "" {
		log.Fatal("migrations path not found")
	}
	m, err := migrate.New("file://"+path, dsn)
	if err != nil {
		log.Fatalf("migrate new: %v", err)
	}
	defer m.Close()
	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		log.Fatalf("migrate up: %v", err)
	}
	log.Printf("migrations applied from %s", path)
}
