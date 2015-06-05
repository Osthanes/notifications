/**
*  Copyright 2014 IBM
*
*   Licensed under the Apache License, Version 2.0 (the "License");
*   you may not use this file except in compliance with the License.
*   You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
*   Unless required by applicable law or agreed to in writing, software
*   distributed under the License is distributed on an "AS IS" BASIS,
*   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*   See the License for the specific language governing permissions and
*   limitations under the License.
*/

var assert = require('assert');
var request = require('request');
var btoa = require('btoa');

var notificationParams = {};

/**
 * notifications.getRecipients
 *
 * @description Get the recipients.
 * @param {object|String}
 *            notificationParams The input parameters
 * @param {function}
 *            callback
 * @returns HOT {*}
 */
var getRecipients = function(notificationParams) {
	theRecipients = "";
	for (var i = 0; i < notificationParams.recipient_info.length; i++) {
		theRecipients = theRecipients + notificationParams.recipient_info[i];
		if ( i < notificationParams.recipient_info.length - 1 ) {
			theRecipients = theRecipients + ",";
		}
	}
	return theRecipients;
};

/**
 * notifications.getSlackChannels
 *
 * @description Get the slack channels.
 * @param {object|String}
 *            notificationParams The input parameters
 * @param {function}
 *            callback
 * @returns HOT {*}
 */
var getSlackChannels = function(notificationParams) {
	theSlackChannels = "";
	for (var i = 0; i < notificationParams.recipient_info.length; i++) {
		theSlackChannels = theSlackChannels + "\"" + notificationParams.recipient_info[i] + "\"";
        if ( i < notificationParams.recipient_info.length - 1 ) {
            theRecipients = theRecipients + ", \"channel\": ";
        }
	}
	return theSlackChannels;
};

/**
 * notifications.getBodyForNotifications
 *
 * @description Get body of the Notification.
 * @param {object|String}
 *            notificationParams The input parameters
 * @param {function}
 *            callback
 * @returns HOT {*}
 */
 var getBodyForNotifications = function(notificationParams) {
    return {
        "channel": notificationParams.channel_type,
        "recipients": [ getRecipients(notificationParams) ],
        "payload": notificationParams.payload_info,
        "options": {
            "subject": notificationParams.subject_info,
            "ibmid": notificationParams.ibmid
        } 
    };
};

/**
 * notifications.getSlackBodyForNotifications
 *
 * @description Get body of the slack Notification.
 * @param {object|String}
 *            notificationParams The input parameters
 * @param {function}
 *            callback
 * @returns HOT {*}
 */
var getSlackBodyForNotifications = function(notificationParams) {
    return {
        "channel": JSON.parse(getSlackChannels(notificationParams)), 
        "username": "Pipeline", 
        "text": notificationParams.payload_info, 
        "icon_emoji": ":traffic_light:"
    };
};

getEmailNotificationParms = function(notificationParams) {
    notificationParams.channel_type = "email";
    notificationParams.recipient_info = process.env.EMAIL.split(",");
    notificationParams.payload_info = process.env.MESSAGE;
    if (process.env.SUBJECT) {
        notificationParams.subject_info = process.env.SUBJECT;
    } else {
        notificationParams.subject_info = "Notification"
    }
    if (process.env.IBM_ID_LOOKUP) {
        notificationParams.ibmid = Boolean (process.env.IBM_ID_LOOKUP);
    } else {
        notificationParams.ibmid = false;
    }
    return notificationParams;
};

getVoiceNotificationParms = function(notificationParams) {
    notificationParams.channel_type = "voice";
    notificationParams.recipient_info = process.env.PHONE.split(",");
    notificationParams.payload_info = process.env.MESSAGE;
    return notificationParams;
}

getTextNotificationParms = function(notificationParams) {
    notificationParams.channel_type = "sms";
    notificationParams.recipient_info = process.env.TXT.split(",");
    notificationParams.payload_info = process.env.MESSAGE;
    return notificationParams;
}

getSlackNotificationParms = function(notificationParams) {
    notificationParams.channel_type = "slack";
    notificationParams.recipient_info = process.env.SLACK_CHANNEL.split(",");
    notificationParams.payload_info = process.env.MESSAGE;
    return notificationParams;
}

getURL = function() {
    return "https://notify-test.services.ibmserviceengage.com/api/send/v1";
}

getSlackWebhookURL = function() {
    return "https://hooks.slack.com/services/" + process.env.SLACK_WEBHOOK_PATH;
}

getSlackApiURL = function() {
    return "https://slack.com/api/chat.postMessage" + process.env.SLACK_TOKEN;
}

getAuthentication = function() {

    //look these up from the environment
    //then these get set on teh stage configuration environmetn proeprties 

    var notify_Id = process.env.NOTIFY_ID;
    var notidy_password = process.env.NOTIFY_PASSWORD;

    return btoa(notify_Id + ":" + notidy_password);
}

describe('Send notifications', function(){
// add before to get authentication information with callback 

    this.timeout(100000);

    if ( process.env.EMAIL ) {
        it('One or more email addresses are specified', function(done){
            console.log("EMAIL is " + process.env.EMAIL);
            notificationParams = getEmailNotificationParms(notificationParams);
            
            describe('the email notification is created and set to the server', function() {
                var options = {
                    url: getURL(),
                    body: getBodyForNotifications(notificationParams),
                    headers: {
                        'Content-Type': 'application/json',
                        'authorization': "Basic " + getAuthentication()
                    },
                    rejectUnauthorized: false,
                    method: 'POST',
                    json:true
                };
                callback =  function (error, response, body) {
                    console.log("Return code for email notification: " + response.statusCode);
                    console.log(body);
                    assert.equal(error, undefined ,"error " + error + " returned when creating email notification " + getURL());
                    assert.equal(response.statusCode, 200, "expected 200 return code from " + getURL() + " but got " + response.statusCode + ", " + body);
                    done();
                };
                request(options,callback);

                it('the email notifications return with success', function(done){

                    done();
                });
            });
        });
    } else {
        it('No email addresses specified', function(done) {done();});
    }


    if ( process.env.PHONE ) {
        it('One or more phone number are specified', function(done){
            console.log("PHONE: " + process.env.PHONE);
            notificationParams = getVoiceNotificationParms(notificationParams);

            describe('the phone notification is created and set to the server', function() {
                var options = {
                    url: getURL(),
                    body: getBodyForNotifications(notificationParams),
                    headers: {
                        'Content-Type': 'application/json',
                        'authorization': "Basic " + getAuthentication()
                    },
                    rejectUnauthorized: false,
                    method: 'POST',
                    json:true
                };
                callback =  function (error, response, body) {
                    console.log("Return code for phone notification: " + response.statusCode);
                    console.log(body);
                    assert.equal(error, undefined ,"error " + error + " returned when creating voice notification " + getURL());
                    assert.equal(response.statusCode, 200, "expected 200 return code from " + getURL() + " but got " + response.statusCode + ", " + body);
                    done();
                };
                request(options,callback);

                it('the phone notifications return with success', function(done){
                    done();
                });
           });
        });
    } else {
        it('No phone numbers specified', function(done) {done();});
    }

    if ( process.env.TXT ) {
        it('One or more text number are specified', function(done){
            console.log("TXT: " + process.env.TXT);
            notificationParams = getTextNotificationParms(notificationParams);

            describe('the text notification is created and set to the server', function() {
                var options = {
                    url: getURL(),
                    body: getBodyForNotifications(notificationParams),
                    headers: {
                        'Content-Type': 'application/json',
                        'authorization': "Basic " + getAuthentication()
                    },
                    rejectUnauthorized: false,
                    method: 'POST',
                    json:true
                };
                callback =  function (error, response, body) {
                    console.log("Return code for text notification: " + response.statusCode);
                    console.log(body);
                    assert.equal(error, undefined ,"error " + error + " returned when creating text notification " + getURL());
                    assert.equal(response.statusCode, 200, "expected 200 return code from " + getURL() + " but got " + response.statusCode + ", " + body);
                    done();
                };
                request(options,callback);

                it('the text notifications return with success', function(done){

                    done();
                });
           });
        });
    } else {
        it('No text numbers specified', function(done) {done();});
    }

    if ( process.env.SLACK_CHANNEL ) {
        it('One or more slack channel are specified', function(done){
            console.log("SLACK_CHANNEL: " + process.env.SLACK_CHANNEL);
            notificationParams = getSlackNotificationParms(notificationParams);

            describe('the slack notification is created and set to the server', function() {
                var options = {
                    url: getSlackWebhookURL(),
                    body: getSlackBodyForNotifications(notificationParams),
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    rejectUnauthorized: false,
                    method: 'POST',
                    json:true
                };
                callback =  function (error, response, body) {
                    console.log("Return code for slack notification: " + response.statusCode);
                    console.log(body);
                    assert.equal(error, undefined ,"error " + error + " returned when creating slack notification " + getURL());
                    assert.equal(response.statusCode, 200, "expected 200 return code from " + getURL() + " but got " + response.statusCode + ", " + body);
                    done();
                };
                request(options,callback);

                it('the slack notifications return with success', function(done){

                    done();
                });
           });
        });
    } else {
        it('No slack channel specified', function(done) {done();});
    }
});


