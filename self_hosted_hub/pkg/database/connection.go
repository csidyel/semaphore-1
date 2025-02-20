package database

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	uuid "github.com/google/uuid"
	postgres "gorm.io/driver/postgres"
	gorm "gorm.io/gorm"
	gormLogger "gorm.io/gorm/logger"
)

type Config struct {
	Host            string
	Port            string
	Name            string
	User            string
	Pass            string
	Ssl             string
	ApplicationName string
}

var dbInstance *gorm.DB

func Conn() *gorm.DB {
	if dbInstance == nil {
		dbInstance = connect()
	}

	return dbInstance.Session(&gorm.Session{})
}

func dbPoolSize() int {
	poolSize := os.Getenv("DB_POOL_SIZE")

	size, err := strconv.Atoi(poolSize)
	if err != nil {
		return 1
	}

	return size
}

func connect() *gorm.DB {
	postgresDbSSL := os.Getenv("POSTGRES_DB_SSL")
	sslMode := "disable"
	if postgresDbSSL == "true" {
		sslMode = "require"
	}

	c := Config{
		Host:            os.Getenv("DB_HOST"),
		Port:            os.Getenv("DB_PORT"),
		Name:            os.Getenv("DB_NAME"),
		Pass:            os.Getenv("DB_PASSWORD"),
		User:            os.Getenv("DB_USERNAME"),
		Ssl:             sslMode,
		ApplicationName: os.Getenv("APPLICATION_NAME"),
	}

	dsnTemplate := "host=%s port=%s user=%s password=%s dbname=%s sslmode=%s application_name=%s"
	dsn := fmt.Sprintf(dsnTemplate, c.Host, c.Port, c.User, c.Pass, c.Name, c.Ssl, c.ApplicationName)

	logger := gormLogger.New(log.New(os.Stdout, "\r\n", log.LstdFlags), gormLogger.Config{
		SlowThreshold:             200 * time.Millisecond,
		LogLevel:                  gormLogger.Warn,
		Colorful:                  true,
		IgnoreRecordNotFoundError: true,
	})

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{Logger: logger})
	if err != nil {
		panic(err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		panic(err)
	}

	sqlDB.SetMaxOpenConns(dbPoolSize())
	sqlDB.SetMaxIdleConns(dbPoolSize())
	sqlDB.SetConnMaxIdleTime(30 * time.Minute)

	return db
}

func TruncateTables() {
	err := Conn().Exec(`
	  truncate table occupation_requests, agents, agent_types;
	`).Error

	if err != nil {
		fmt.Printf("%s\n", err)
		panic("Failed to purge database")
	}
}

func UUID() uuid.UUID {
	id, _ := uuid.NewRandom()
	return id
}
