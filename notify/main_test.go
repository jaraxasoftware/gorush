package notify

import (
	"log"
	"os"
	"testing"

	"github.com/jaraxasoftware/gorush/config"
	"github.com/jaraxasoftware/gorush/status"
)

func TestMain(m *testing.M) {
	cfg, _ := config.LoadConf()
	if err := status.InitAppStatus(cfg); err != nil {
		log.Fatal(err)
	}

	os.Exit(m.Run())
}
