package gorush

import (
	"errors"
	"fmt"
	"strconv"

	"github.com/jaraxasoftware/gorush/web"
)

// InitWebClient use for initialize APNs Client.
func InitWebClient() error {
	if PushConf.Web.Enabled {
		//var err error
		WebClient = web.NewClient()
	}

	return nil
}

func getWebNotification(req PushNotification, subscription *Subscription) *web.Notification {
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
func PushToWeb(req PushNotification) bool {
	LogAccess.Debug("Start push notification for Web")
	var doSync = req.sync
	if doSync {
		defer req.WaitDone()
	}

	var retryCount = 0
	var maxRetry = PushConf.Web.MaxRetry

	if req.Retry > 0 && req.Retry < maxRetry {
		maxRetry = req.Retry
	}

	// check message
	err := CheckMessage(req)

	if err != nil {
		LogError.Error("request error: " + err.Error())
		return false
	}

	var apiKey = PushConf.Web.APIKey
	if req.APIKey != "" {
		apiKey = req.APIKey
	}

Retry:
	var isError = false

	successCount := 0
	failureCount := 0

	for _, subscription := range req.Subscriptions {
		notification := getWebNotification(req, &subscription)
		response, err := WebClient.Push(notification, apiKey)
		webToken := "{\"endpoint\":\"" + subscription.Endpoint + "\",\"key\":\"" + subscription.Key + "\",\"auth\":\"" + subscription.Auth + "\"}"
		if err != nil {
			isError = true
			failureCount++
			LogPush(FailedPush, subscription.Endpoint, req, err)
			fmt.Println(err)
			if doSync {
				if response == nil {
					req.AddLog(getLogPushEntry(FailedPush, webToken, req, err))
				} else {
					var errorText = response.Body
					/*var browser web.Browser
					var found = false
					for _, current := range web.Browsers {
						if current.ReDetect.FindString(subscription.Endpoint) != "" {
							browser = current
							found = true
						}
					}
					if found {
						match := browser.ReError.FindStringSubmatch(errorText)
						if match != nil && len(match) > 1 && match[1] != "" {
							errorText = match[1]
						}
					}*/
					errorText = strconv.Itoa(response.StatusCode);
					var errorObj = errors.New(errorText)
					req.AddLog(getLogPushEntry(FailedPush, webToken, req, errorObj))
				}
			}
		} else {
			isError = false
			successCount++
			LogPush(SucceededPush, webToken, req, nil)
		}
	}

	LogAccess.Debug(fmt.Sprintf("Web Success count: %d, Failure count: %d", successCount, failureCount))
	StatStorage.AddWebSuccess(int64(successCount))
	StatStorage.AddWebError(int64(failureCount))

	if isError && retryCount < maxRetry {
		retryCount++

		goto Retry
	}

	return isError
}
