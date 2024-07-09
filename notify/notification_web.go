package notify

import (
	"context"
	"errors"
	"strconv"

	"github.com/jaraxasoftware/gorush/config"
	"github.com/jaraxasoftware/gorush/core"
	"github.com/jaraxasoftware/gorush/logx"
	"github.com/jaraxasoftware/gorush/web"
)

// InitWebClient use for initialize APNs Client.
func InitWebClient(ctx context.Context, cfg *config.ConfYaml) (*web.Client, error) {
	if cfg.Web.Enabled {
		if cfg.Web.VAPIDPrivateKey == "" ||
			cfg.Web.VAPIDPublicKey == "" {
			return nil, errors.New("missing web VAPID data")
		}
	}

	if WebClient != nil {
		return WebClient, nil
	}

	WebClient = web.NewClient(cfg.Web.VAPIDPrivateKey, cfg.Web.VAPIDPublicKey)
	return WebClient, nil
}

func getWebNotification(req *PushNotification, subscription *Subscription) *web.Notification {
	notification := &web.Notification{
		Payload: (*map[string]interface{})(&req.Data),
		Subscription: &web.Subscription{
			Endpoint: subscription.Endpoint,
			Key:      subscription.Key,
			Auth:     subscription.Auth,
		},
		TimeToLive: req.TimeToLive,
	}
	return notification
}

// PushToWeb provide send notification to Web server.
func PushToWeb(ctx context.Context, req *PushNotification, cfg *config.ConfYaml) (resp *ResponsePush, err error) {
	logx.LogAccess.Debug("Start push notification for Web")

	var retryCount = 0
	var maxRetry = cfg.Web.MaxRetry

	if req.Retry > 0 && req.Retry < maxRetry {
		maxRetry = req.Retry
	}

	// check message
	err = CheckMessage(req)

	if err != nil {
		logx.LogError.Error("request error: " + err.Error())
		return nil, err
	}

Retry:

	successCount := 0
	failureCount := 0
	resp = &ResponsePush{}

	var newSubscriptions []Subscription

	for _, subscription := range req.Subscriptions {
		notification := getWebNotification(req, &subscription)
		response, err := WebClient.Push(notification)

		if err != nil {
			if response != nil {
				var errorText = response.Body

				errorText = strconv.Itoa(response.StatusCode)
				err = errors.New(errorText)
			}
			failureCount++
			errLog := logPush(cfg, core.FailedPush, subscription.Endpoint, req, err)
			resp.Logs = append(resp.Logs, errLog)
			newSubscriptions = append(newSubscriptions, subscription)
		} else {
			successCount++
			logPush(cfg, core.SucceededPush, subscription.Endpoint, req, nil)
		}
	}

	if len(newSubscriptions) > 0 && retryCount < maxRetry {
		retryCount++

		// resend fail token
		req.Subscriptions = newSubscriptions
		goto Retry
	}

	return resp, nil
}
