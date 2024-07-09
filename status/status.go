package status

import (
	"errors"

	"github.com/jaraxasoftware/gorush/config"
	"github.com/jaraxasoftware/gorush/core"
	"github.com/jaraxasoftware/gorush/logx"
	"github.com/jaraxasoftware/gorush/storage/badger"
	"github.com/jaraxasoftware/gorush/storage/boltdb"
	"github.com/jaraxasoftware/gorush/storage/buntdb"
	"github.com/jaraxasoftware/gorush/storage/leveldb"
	"github.com/jaraxasoftware/gorush/storage/memory"
	"github.com/jaraxasoftware/gorush/storage/redis"

	"github.com/thoas/stats"
)

// Stats provide response time, status code count, etc.
var Stats *stats.Stats

// StatStorage implements the storage interface
var StatStorage *StateStorage

// App is status structure
type App struct {
	Version        string        `json:"version"`
	BusyWorkers    int           `json:"busy_workers"`
	SuccessTasks   int           `json:"success_tasks"`
	FailureTasks   int           `json:"failure_tasks"`
	SubmittedTasks int           `json:"submitted_tasks"`
	TotalCount     int64         `json:"total_count"`
	Ios            IosStatus     `json:"ios"`
	Android        AndroidStatus `json:"android"`
	Web            WebStatus     `json:"web"`
	Huawei         HuaweiStatus  `json:"huawei"`
}

// AndroidStatus is android structure
type AndroidStatus struct {
	PushSuccess int64 `json:"push_success"`
	PushError   int64 `json:"push_error"`
}

// IosStatus is iOS structure
type IosStatus struct {
	PushSuccess int64 `json:"push_success"`
	PushError   int64 `json:"push_error"`
}

// WebStatus is web structure
type WebStatus struct {
	PushSuccess int64 `json:"push_success"`
	PushError   int64 `json:"push_error"`
}

// HuaweiStatus is huawei structure
type HuaweiStatus struct {
	PushSuccess int64 `json:"push_success"`
	PushError   int64 `json:"push_error"`
}

// InitAppStatus for initialize app status
func InitAppStatus(conf *config.ConfYaml) error {
	logx.LogAccess.Info("Init App Status Engine as ", conf.Stat.Engine)

	var store core.Storage
	//nolint:goconst
	switch conf.Stat.Engine {
	case "memory":
		store = memory.New()
	case "redis":
		store = redis.New(
			conf.Stat.Redis.Addr,
			conf.Stat.Redis.Password,
			conf.Stat.Redis.DB,
			conf.Stat.Redis.Cluster,
		)
	case "boltdb":
		store = boltdb.New(
			conf.Stat.BoltDB.Path,
			conf.Stat.BoltDB.Bucket,
		)
	case "buntdb":
		store = buntdb.New(
			conf.Stat.BuntDB.Path,
		)
	case "leveldb":
		store = leveldb.New(
			conf.Stat.LevelDB.Path,
		)
	case "badger":
		store = badger.New(
			conf.Stat.BadgerDB.Path,
		)
	default:
		logx.LogError.Error("storage error: can't find storage driver")
		return errors.New("can't find storage driver")
	}

	StatStorage = NewStateStorage(store)

	if err := StatStorage.Init(); err != nil {
		logx.LogError.Error("storage error: " + err.Error())

		return err
	}

	Stats = stats.New()

	return nil
}
