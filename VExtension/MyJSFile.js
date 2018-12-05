var MyExtensionJavaScriptClass = function() {};

MyExtensionJavaScriptClass.prototype = {
run: function(arguments) {
    var originURL = document.URL ? document.URL : ""; //网站地址
    var videoInfo = { title: "unknow", url:"", poster:"", duration:"", type:"video/mp4", source:originURL }; // 视频信息
    
    if (document.title) {
        videoInfo.title = document.title;
    }
    
    // 转换时间
    function seconds2time (seconds) {
        seconds = Math.ceil(seconds);
        var hours   = Math.floor(seconds / 3600);
        var minutes = Math.floor((seconds - (hours * 3600)) / 60);
        var seconds = seconds - (hours * 3600) - (minutes * 60);
        var time = "";
        
        if (hours != 0) {
            time = hours+":";
        }
        if (minutes != 0 || time !== "") {
            minutes = (minutes < 10 && time !== "") ? "0"+minutes : String(minutes);
            time += minutes+":";
        }
        if (time === "") {
            time = (seconds < 10) ? "0:0"+seconds : "0:"+String(seconds);
        }
        else {
            time += (seconds < 10) ? "0"+seconds : String(seconds);
        }
        return time;
    }
    
    // URL Last component
    function urlLastComponent(url) {
        var tUrl = new URL(url);
        var tComps = tUrl.pathname.split('/');
        var lastComp = tComps.pop();
        return lastComp.slice(0,-4);
    }
    
    // 判断元素是否在viewport中
    function isElementInViewport (el) {
        
        //special bonus for those using jQuery
        if (typeof jQuery === "function" && el instanceof jQuery) {
            el = el[0];
        }
        
        var rect = el.getBoundingClientRect();
        
        return (
                rect.top >= 0 &&
                rect.left >= 0 &&
                rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) && /*or $(window).height() */
                rect.right <= (window.innerWidth || document.documentElement.clientWidth) ||/*or $(window).width() */
                rect.top < (window.innerHeight/2 || document.documentElement.clientHeight/2) &&
                rect.bottom > (window.innerHeight/2 || document.documentElement.clientHeight/2)
                );
    }
    
    // 解析Youtube
    function youtubeParse() {
        // youtube
        var elem = document.getElementsByTagName("video")[0];
        var vIndex = document.URL.search('v=');
        var vId = document.URL.slice(vIndex+2);
        // 解析URL 获得时长
        var searchs = elem.src.split('?')[1].split('&');
        for (var pairs of searchs) {
            if (pairs.includes('dur=')) {
                var dur = pairs.split('=')[1];
                videoInfo.duration = seconds2time(parseInt(dur,10));
                break;
            }
        }
        
        videoInfo.title = elem.title;
        videoInfo.url = elem.src;
        videoInfo.poster = "https://i.ytimg.com/vi/" + vId + "/hqdefault.jpg";
    }
    
    // 解析youku
    function youkuParse() {
        var elem = document.getElementsByTagName("video")[0]; // 在iPad上会给出flv类型的视频
        if (elem.src.includes('flv')) {
            elem.src = elem.src.replace('flv','mp4');
        }
        
        var detail = document.getElementsByClassName('detail-h')[0];
        
        if (detail) {
            videoInfo.title = detail.firstChild.textContent.trim();
        }
        videoInfo.url = elem.src;
        var duration = document.getElementsByClassName('x-video-state')[0].textContent;
        if (duration) {
            videoInfo.duration = duration;
        } else {
            videoInfo.duration = document.getElementsByClassName('x-time-duration')[0].textContent; // v.youku 可能只显示在这里
        }
        videoInfo.poster = document.getElementsByClassName('x-video-poster')[0].firstChild.src;
    }
    
    // 解析gfycat
    function gfycatParse() {
        var sources = document.getElementsByTagName("source");
        var elem;
        for (var i = 0; i < sources.length; i++) {
            var source = sources[i];
            if (source.type.includes("video/mp4")) {
                elem = source;
                break;
            }
        }
        
        videoInfo.title = urlLastComponent(elem.src);
        videoInfo.url = elem.src;
        videoInfo.poster = elem.parentNode.poster;
        
        var duration_seconds = elem.parentNode.duration;
        if (duration_seconds) {
            videoInfo.duration = seconds2time(duration_seconds);
        }
    }
    
    // 解析bilibili
    function bilibiliParse() {
        var preTitle = document.querySelector("head>meta[property='og:title']").content;
        var prePoster = document.querySelector("head>meta[property='og:image']").content;
        
        if (preTitle) {
            videoInfo.title = preTitle;
        }
        
        if (prePoster) {
            videoInfo.poster = prePoster;
        }
    
        videoInfo.url = document.getElementsByTagName('source')[0].src;
        videoInfo.duration = document.getElementsByClassName('time-total-text')[0].textContent;
    }
    
    
    
    // 解析twimg
    function twimgParse() {
        var vmap = document.head.querySelector("meta[name='twitter:amplify:vmap']").content;
        var durationStr = document.head.querySelector("meta[name='twitter:amplify:content_duration_seconds']").content;
        var elem = document.getElementById('iframe').contentWindow.document.getElementsByTagName('video')[0];
        
        videoInfo.title = document.title;
        videoInfo.url = vmap;
        videoInfo.duration = seconds2time(parseInt(durationStr,10));
        videoInfo.poster = elem.poster;
        videoInfo.type = "xml";
    }
    
    // 腾讯视频
    function qqParse() {
        var tvp_title = document.getElementsByClassName('tvp_title')[0];
        if (tvp_title) {
            videoInfo.title = tvp_title.textContent;
        } else {
            videoInfo.title = document.getElementsByClassName('video_title')[0].textContent;
        }
        
        if (videoInfo.source.includes('m.v.qq')) {
            videoInfo.url = document.querySelector('a[class=tvp_app_btn]').getAttribute('data-url'); // iPhone
        } else {
            videoInfo.url = document.querySelector('a[class=tvp_open_btn_a]').getAttribute('data-openurl');
        }
        
        var tvp_time_panel_total = document.getElementsByClassName('tvp_time_panel_total')[0];
        if (tvp_time_panel_total) {
            videoInfo.duration = tvp_time_panel_total.textContent;
        } else {
            videoInfo.duration = document.getElementsByClassName('txp_time_duration')[0].textContent;
        }
        
        
        var meta = document.querySelector('meta[itemprop="image"]');
        if (meta) {
            videoInfo.poster = meta.content;
        } else {
            videoInfo.poster = "https:" + document.getElementsByClassName('tvp_poster_img')[0].getAttribute('data-pic');
        }
        
        videoInfo.type = "qq";
    }
    
    // 秒拍
    function miaopaiParse() {
        var videoElem = document.getElementById('video');
        videoInfo.title =  document.querySelector('meta[name="description"]').content;
        videoInfo.url = videoElem.src;
        videoInfo.poster = document.getElementsByClassName('video_img')[0].dataset.url;
        
        var duration_seconds = videoElem.duration;
        if (duration_seconds) {
            videoInfo.duration = seconds2time(duration_seconds);
        }
    }
    
    // weibo
    function weiboParse() {
        otherParse();
        var description = document.querySelector('meta[name="description"]');
        if (description) {
            videoInfo.title = description.content;
        } else {
            videoInfo.title = document.getElementsByClassName('weibo-detail')[0].getElementsByClassName('default-content')[0].textContent
        }
        
        var poster = document.getElementsByClassName('poster')[0];
        if (poster) {
            videoInfo.poster = poster.src;
        }
    }
    
    // tumblr
    function tumblrParse() {
        otherParse();
        if (videoInfo.url.length == 0) {
            // 获取iframe
            var vFrames = document.getElementsByClassName('tumblr_video_iframe');
            var vFrame;
            for (var i = 0; i < vFrames.length; i++) {
                var f = vFrames[i];
                if (isElementInViewport(f)) {
                    vFrame = f;
                    break;
                }
            }
            
            if (vFrame) {
                videoInfo.title = "iframe";
                videoInfo.url = vFrame.src;
                videoInfo.type = "iframe";
            }
        }
    }
    
    // xvideos
    function xvideosParse() {
        otherParse();
        if (videoInfo.url.length == 0) {
            var html5video = document.getElementById('html5video');
            var sibling = html5video.nextElementSibling;
            
            while (sibling.nextElementSibling) {
                if (sibling.text &&sibling.text.length > 0) break;
                
                sibling = sibling.nextElementSibling;
            }
            
            
            var infoArr = sibling.innerHTML.split(';').filter(function(ele) {
                                                                 return ele.includes('setVideoTitle') || ele.includes('setVideoUrlHigh') || ele.includes('setThumbUrl')
                                                                 });
            
            for (var i = 0;i < infoArr.length;i++) {
                var info = infoArr[i];
                if (info.includes('setVideoTitle')) {
                    videoInfo.title = info.split("'")[1];
                }
                
                if (info.includes('setVideoUrlHigh')) {
                    videoInfo.url = info.split("'")[1];
                }
                
                if (info.includes('setThumbUrl')) {
                    videoInfo.poster = info.split("'")[1];
                }
            }
        }
    }
    
    // acfun
    function acfunParse() {
        var playerFrame = document.getElementById('player');
        var itemInfo = playerFrame.getAttribute('src').split(';');
        
        videoInfo.poster = itemInfo[1].split('=')[1];
        videoInfo.title = itemInfo[2].split('=')[1];
        videoInfo.url = playerFrame.contentDocument.getElementsByTagName('video')[0].src;
        videoInfo.duration = playerFrame.contentDocument.getElementsByClassName('totalTime')[0].innerText;
    }
    
    // vimeo
    function vimeoParse() {
        var player_containers = document.getElementsByClassName('player_container');
        
        var current_player_container;
        for (var i = 0; i < player_containers.length; i++) {
            var p = player_containers[i];
            if (isElementInViewport(p)) {
                current_player_container = p;
                break;
            }
        }
        
        // channel ??
        if (videoInfo.source.includes('channels')) {
            videoInfo.title = current_player_container.getElementsByTagName('video')[0].title;
            videoInfo.poster = current_player_container.getElementsByClassName('video')[0].getAttribute('data-thumb');
            var clipID = document.getElementsByClassName('stats-debug-clip-id')[0].textContent;
            videoInfo.url = "https://player.vimeo.com/video/" + clipID +"/config";
        } else {
            var player_thumb = current_player_container.getElementsByClassName('player_thumb')[0]
            
            videoInfo.title =  player_thumb.alt;
            videoInfo.poster = player_thumb.src;
            videoInfo.url = current_player_container.getElementsByClassName('player')[0].getAttribute('data-config-url');
        }
        
        videoInfo.duration = current_player_container.getElementsByClassName("mobile-timecode")[0].textContent;
        
        videoInfo.type = "vimeo";
    }
    
    // 解析twitter
    function twitterParse() {
        const regex = /\d{15,}/;
        var tweet_id = videoInfo.source.match(regex)[0];
        
        videoInfo.type = "twitter";
        videoInfo.url = "https://api.twitter.com/1.1/statuses/show/" + tweet_id + ".json?tweet_mode=extended";
    }
    
    function otherParse() {
        // 其他网站
        var sources = document.getElementsByTagName("source");
        var elem;
        for (var i = 0; i < sources.length; i++) {
            var source = sources[i];
            if (source.type.includes("video/mp4") || source.src.endsWith(".mp4")) {
                elem = source;
                break;
            }
        }
        
        var videos = document.getElementsByTagName('video');
        if (videos.length > 0) {
            var video = videos[0];
            var poster = video.poster;
            var duration_seconds = video.duration;
            if (poster) {
                videoInfo.poster = poster;
            }
            
            if (duration_seconds) {
                videoInfo.duration = seconds2time(duration_seconds)
            }
            
            if (elem) {
                videoInfo.url = elem.src;
            } else {
                for (var i = 0; i < videos.length; i++) {
                    var vd = videos[i];
                    if (vd.src) {
                        if (vd.src.includes('mp4')) {
                            videoInfo.url = vd.src;
                            break;
                        }
                        
                        var vd_type = vd.getAttribute('type');
                        if (vd_type) {
                            if (vd_type.includes("video/mp4")) {
                                videoInfo.url = vd.src;
                                break;
                            }
                        }
                    }
                }
            }
            
            if (videoInfo.title.length == 0) {
                if (videoInfo.url) {
                    videoInfo.title = urlLastComponent(videoInfo.url);
                } else {
                    videoInfo.title = "unKnow title"
                }
            }
        }
    }

    if (originURL.includes('youtube.com')) {
        youtubeParse();
    } else if (originURL.includes('youku.com')) {
        youkuParse();
    } else if (originURL.includes('gfycat.com')) {
        gfycatParse();
    } else if (originURL.includes('bilibili.com')) {
        bilibiliParse();
    } else if (originURL.includes('twitter.com')) {
        twitterParse();
    } else if (originURL.includes('amp.twimg.com')) {
        twimgParse();
    } else if (originURL.includes('v.qq.com')) {
        qqParse();
    } else if (originURL.includes('miaopai.com')) {
        miaopaiParse();
    } else if (originURL.includes('.weibo.')) {
        weiboParse();
    } else if (originURL.includes('tumblr.com')) {
        tumblrParse();
    } else if (originURL.includes('xvideos.com')) {
        xvideosParse();
    } else if (originURL.includes('m.aixifan.com') || originURL.includes('acfun.tv')) {
        acfunParse();
    } else if (originURL.includes('vimeo.com')) {
        vimeoParse();
    } else {
        otherParse();
    }
    
    arguments.completionFunction({"videoInfo":videoInfo});
},
    
    // Note that the finalize function is only available in iOS.
finalize: function(arguments) {
    // arguments contains the value the extension provides in [NSExtensionContext completeRequestReturningItems:completion:].
    // In this example, the extension provides a color as a returning item.
    document.body.style.backgroundColor = arguments["bgColor"];
}
};

// The JavaScript file must contain a global object named "ExtensionPreprocessingJS".
var ExtensionPreprocessingJS = new MyExtensionJavaScriptClass;
