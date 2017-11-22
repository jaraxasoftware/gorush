package gorush

import (
	"github.com/jaraxasoftware/gorush/config"
	"github.com/jaraxasoftware/gorush/storage"
	"github.com/jaraxasoftware/gorush/web"

	"github.com/appleboy/go-fcm"
	"github.com/sideshow/apns2"
	"github.com/sirupsen/logrus"
)

var (
	// PushConf is gorush config
	PushConf config.ConfYaml
	// QueueNotification is chan type
	QueueNotification chan PushNotification
	// ApnsClient is apns client
	ApnsClient *apns2.Client
	// VoipApnsClient is apns client
	VoipApnsClient *apns2.Client
	// FCMClient is apns client
	FCMClient *fcm.Client
	// WebClient is web client
	WebClient *web.Client
	// LogAccess is log server request log
	LogAccess *logrus.Logger
	// LogError is log server error log
	LogError *logrus.Logger
	// StatStorage implements the storage interface
	StatStorage storage.Storage
)
