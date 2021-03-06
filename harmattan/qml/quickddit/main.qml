/*
    Quickddit - Reddit client for mobile phones
    Copyright (C) 2014  Dickson Leong
    Copyright (C) 2015  Sander van Grieken

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see [http://www.gnu.org/licenses/].
*/

import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.1
import Quickddit.Core 1.0

PageStackWindow {
    id: appWindow
    showStatusBar: inPortrait
    initialPage: Component { MainPage {} }

    InfoBanner {
        id: infoBanner
        topMargin: showStatusBar ? 40 : 8

        function alert(text) {
            infoBanner.text = text
            infoBanner.show()
        }

        function warning(text) {
            // TODO differentiate icon between alert/warning
            alert(text);
        }
    }

    QtObject {
        id: globalUtils

        property Component __openLinkDialogComponent: null
        property Component __selectionDialogComponent: Component { SelectionDialog {} }
        property Component __listModelComponent: Component { ListModel {} }
        property Component __queryDialogComponent: Component { QueryDialog {} }

        function previewableImage(url) {
            // imgur url
            if (/^https?:\/\/((i|m)\.)?imgur\.com/.test(url))
                return true;
            // reddituploads
            else if (/^https?:\/\/i.reddituploads.com\//.test(url))
                return true;
            // direct image url with image format extension
            else if (/^https?:\/\/\S+\.(jpe?g|png|gif)/i.test(url))
                return true;
            else
                return false;
        }

        function openImageViewPage(url) {
            if (/^https?:\/\/((i|m)\.)?imgur\.com/.test(url))
                pageStack.push(Qt.resolvedUrl("ImageViewPage.qml"), {imgurUrl: url});
            else if (/^https?:\/\/i.reddituploads.com\//.test(url))
                pageStack.push(Qt.resolvedUrl("ImageViewPage.qml"), {imageUrl: url});
            else if (/^https?:\/\/\S+\.(jpe?g|png|gif)/i.test(url))
                pageStack.push(Qt.resolvedUrl("ImageViewPage.qml"), {imageUrl: url});
            else
                infoBanner.alert(qsTr("Unsupported image url"));
        }

        function redditLink(url) {
            if (/^https?:\/\/(\w+\.)?reddit.com(\/r\/\w+)?\/comments\/\w+/.test(url))
                return true;
            else if (/^https?:\/\/(\w+\.)?reddit.com\/r\/(\w+)\/?/.test(url))
                return true;
            else if (/^https?:\/\/(\w+\.)?reddit.com\/u(ser)?\/(\w+)\/?/.test(url))
                return true;
            else if (/^https?:\/\/(\w+\.)?reddit.com\/message\/compose\/?\?/.test(url))
                return true;
            return false
        }

        function openRedditLink(url) {
            if (/^https?:\/\/(\w+\.)?reddit.com(\/r\/\w+)?\/comments\/\w+/.test(url))
                pageStack.push(Qt.resolvedUrl("CommentPage.qml"), {linkPermalink: url});
             else if (/^https?:\/\/(\w+\.)?reddit.com\/r\/(\w+)\/?/.test(url)) {
                var subreddit = /^https?:\/\/(\w+\.)?reddit.com\/r\/(\w+)\/?/.exec(url)[2];
                var mainPage = pageStack.find(function(page) { return page.objectName == "mainPage"; });
                mainPage.refresh(subreddit);
                pageStack.pop(mainPage);
            } else if (/^https?:\/\/(\w+\.)?reddit.com\/u(ser)?\/(\w+)\/?/.test(url)) {
                var username = /^https?:\/\/(\w+\.)?reddit.com\/u(ser)?\/(\w+)\/?/.exec(url)[3];
                pageStack.push(Qt.resolvedUrl("UserPage.qml"), {username: username});
            } else if (/^https?:\/\/(\w+\.)?reddit.com\/message\/compose\/?\?(.*)/.test(url)) {
                var urlparams = /^https?:\/\/(\w+\.)?reddit.com\/message\/compose\/?\?(.*)/.exec(url)[2].split("&");
                var params = {}
                for (var i=0; i < urlparams.length; i++) {
                    var kvp = urlparams[i].split("=");
                    params[kvp[0]] = kvp[1];
                }
                params["recipient"] = params["to"]
                params["message"] = decodeURIComponent(params["message"])
                pageStack.push(Qt.resolvedUrl("NewMessagePage.qml"), params);
            } else
                infoBanner.alert(qsTr("Unsupported reddit url"));
        }

        function openLink(url) {
            url = QMLUtils.toAbsoluteUrl(url);
            if (!url)
                return;

            if (previewableImage(url))
                openImageViewPage(url);
            else if (redditLink(url))
                openRedditLink(url);
            else
                createOpenLinkDialog(url);
        }

        function openNonPreviewLink(url, source) {
            url = QMLUtils.toAbsoluteUrl(url);
            if (url) {
                source = QMLUtils.toAbsoluteUrl(source);
                if (source === url) {
                    source = undefined;
                }

                createOpenLinkDialog(url,source);
            }
        }

        function createOpenLinkDialog(url, source) {
            if (!__openLinkDialogComponent)
                __openLinkDialogComponent = Qt.createComponent("OpenLinkDialog.qml");
            var dialog = __openLinkDialogComponent.createObject(pageStack.currentPage, {url: url, source: source});
            dialog.statusChanged.connect(function() {
                if (dialog.status == DialogStatus.Closed)
                    dialog.destroy(250);
            });
            dialog.open();
        }

        function createSelectionDialog(title, model, selectedIndex, onAccepted) {
            // convert array (model) to ListModel because SelectionDialog can not accept array
            var listModel = __listModelComponent.createObject(null);
            model.forEach(function(m) { listModel.append({ "text": m }) });

            var p = {titleText: title, model: listModel, selectedIndex: selectedIndex};
            var dialog = __selectionDialogComponent.createObject(pageStack.currentPage, p);
            dialog.statusChanged.connect(function() {
                if (dialog.status == DialogStatus.Closed) {
                    dialog.destroy(250);
                    listModel.destroy();
                }
            });
            dialog.accepted.connect(function() { onAccepted(dialog.selectedIndex) });
            dialog.open();
        }

        function createQueryDialog(title, message, onAccepted) {
            var p = { titleText: title, message: message, acceptButtonText: qsTr("Yes"), rejectButtonText: qsTr("No") };
            var dialog = __queryDialogComponent.createObject(pageStack.currentPage, p);
            dialog.statusChanged.connect(function() {
                if (dialog.status == DialogStatus.Closed)
                    dialog.destroy(250);
            });
            dialog.accepted.connect(onAccepted);
            dialog.open();
        }
    }

    Constant { id: constant }
    AppSettings { id: appSettings }

    Binding {
        target: theme
        property: "inverted"
        value: !appSettings.whiteTheme
    }

    QuickdditManager {
        id: quickdditManager
        settings: appSettings
        onAccessTokenFailure: {
            if (code == 299 /* QNetworkReply::UnknownContentError */) {
                infoBanner.alert(qsTr("Please log in again"));
                pageStack.push(Qt.resolvedUrl("AppSettingsPage.qml"));
            } else {
                infoBanner.alert(errorString);
            }
        }
    }

    InboxManager {
        id: inboxManager
        manager: quickdditManager
        enabled: appSettings.pollUnread

        property bool hasUnseenUnread: false

        function dismiss() {
            hasUnseenUnread = false;
        }

        function publishReplies(messages) {
            var result = [];
            for (var i=0; i < messages.length; i++) {
                if (messages[i].isComment === true) {
                    result.push(messages[i]);
                }
            }
            if (result.length > 0)
                QMLUtils.publishNotification(
                        result[0].subject,
                        "in /r/" + result[0].subreddit + " by " + result[0].author
                            + (result.length === 1 ? "" : qsTr(" and %1 other").arg(result.length-1)),
                        result.length);
        }

        function publishMessages(messages) {
            for (var i=0; i < messages.length; i++) {
                if (messages[i].isComment === false) {
                    QMLUtils.publishNotification(
                            qsTr("Message from %1").arg(messages[i].author),
                            messages[i].rawBody,
                            1);
                }
            }
        }

        onNewUnread: {
            if (Qt.application.active) {
                infoBanner.alert(messages.length === 1
                                 ? qsTr("New message from %1").arg(messages[0].author)
                                 : qsTr("%n new messages", "0", messages.length));
            } else {
                publishReplies(messages);
                publishMessages(messages);
            }
            hasUnseenUnread = true;
        }

        onError: console.log(error);
    }

    Connections {
        target: DbusApp
        onRequestMessageView: {
            if (pageStack.currentPage.objectName === "messagePage") {
                pageStack.currentPage.refresh();
            } else {
                pageStack.push(Qt.resolvedUrl("MessagePage.qml"));
            }
        }
    }

}
