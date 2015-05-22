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
 * @description Get the body of the recipients.
 * @param {object|String}
 *            notificationParams The input parameters
 * @param {function}
 *            callback
 * @returns HOT {*}
 */
var getRecipients = function(notificationParams) {
	theRecipients = "\"recipients\": [ ";
	for (var i = 0; i < notificationParams.recipient_info.length; i++) {
		theRecipients = theRecipients + "\""+ notificationParams.recipient_info[i] + "\"";
		if ( i < notificationParams.recipient_info.length - 1 ) {
			theRecipients = theRecipients + ",";
		}
	}
	return theRecipients + "],";
};

/**
 * notifications.getBodyForNotifications
 *
 * @description Get the body of the Notification.
 * @param {object|String}
 *            notificationParams The input parameters
 * @param {function}
 *            callback
 * @returns HOT {*}
 */
 var getBodyForNotifications = function(notificationParams) {
    theBody =  "{"
               + "\"channel\": \""+ notificationParams.channel_type + "\","
               + getRecipients(notificationParams)
     + "\"payload\": \""+ notificationParams.payload_info + "\"";
    if (( notificationParams.channel_type === "email")) {
        theBody = theBody
               + ",\"options\": {"
               + "\"subject\": \""+ notificationParams.subject_info + "\","
               + "\"ibmid\": "+ notificationParams.ibmid
        + "}";
    }
    theBody = theBody + "}";
    return theBody;
};

describe('Send notifications for email', function(){
    it('if one or more email addresses are specified', function(){
        if ( process.env.EMAIL ) {
            console.log("Hello World");
            console.log("EMAIL is "+process.env.EMAIL);
            notificationParams.channel_type = "email";
            notificationParams.recipient_info = process.env.EMAIL.split(",");
            notificationParams.payload_info = process.env.MESSAGE;
            notificationParams.subject_info = process.env.SUBJECT;
            if (process.env.IBM_ID_LOOKUP) {
                notificationParams.ibmid = Boolean (process.env.IBM_ID_LOOKUP);
            } else {
                notificationParams.ibmid = false;
            }

            describe('the JSON is created and set to the server', function() {
                console.log ("starting JSON");
                var url= "https://notify-test.services.ibmserviceengage.com/api/send/v1";
                var userId = "test2/fihhohnycvic";
                var password = "yrxZxgRBtCqCcCNOQwvHELtMVwwazDyt";
                var auth = btoa(userId + ":" + password);
                var options = {
                    url: url,
                    body: getBodyForNotifications(notificationParams),
                    headers: {"Content-Type": "application/json", "Accept": "application/json", "Authentication": "Basic " + auth},
                    rejectUnauthorized: false,
                    method: "POST"
                };
                console.log("here is my auth: " + auth);
                console.log("here is my options" + options);
                console.log("body" + options.body);

                //console.log("options:" + options)
            callback =  function (error, response, body) {
                    console.log("here I am");
                    console.log(response.statusCode);
                    console.log(body);
                    assert.equal(error, undefined ,"error " + error + " returned when creating email notification " + url);
                    assert.equal(response.statusCode, 200, "expected 200 return code from " + url + " but got " + response.statusCode + ", " + body);
                };
                console.log("Before request");
                request(options,callback);

                it('the notifications return with success', function(){});
            });
        }
    });
});


