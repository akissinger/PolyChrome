(function() {
    
var log = PolyMLext.log;
var error = PolyMLext.error;

//shortcut
var e = function(id) { return document.getElementById(id) }

PolyMLext.BrowserUI = function() {
    
    this.prefs = {};
    this.prefs.alwaysEnabled = Application.prefs.get(
            "extensions.polymlext@ed.ac.uk.alwaysEnabled");
    this.prefs.PolyMLPath = Application.prefs.get(
            "extensions.polymlext@ed.ac.uk.PolyMLPath");
    this.console = new ConsoleUI(this);
}
PolyMLext.BrowserUI.prototype = {
    activeConsole : null,
    callbacks : null,
    
    prefs : null,
    
    links : {
        settings    : 'chrome://polymlext/content/settings.html',
        demos       : 'chrome://polymlext/content/demos/index.html',
        construct   : 'chrome://polymlext/content/theConstruct.html',
        docs        : 'chrome://polymlext/content/docs/index.html'
    },
    
    noPoly : function() {
        var self = this;
        e("polymlext-button-console").setAttribute("hidden", true);
        e("polymlext-button-nopoly").setAttribute("hidden", false);
        e("polymlext-button-nopoly").addEventListener("click", function() {
                self.displaySettingsPage();
            }, false);
        
        this.setGlobalStatus({s:"PolyML not found"});
    },
    
    bindContextMenu : function() {
        var self = this;
        
        //demos
        e("polymlext-button-demos").addEventListener("click", function() {
                self.displayDemosPage();
            }, false);
        
        //The Construct (from The Matrix :)
        e("polymlext-button-construct").addEventListener("click", function() {
                gBrowser.selectedTab = gBrowser.addTab(self.links.construct);
            }, false);
        //always enabled option
        e("polymlext-button-alwaysEnable").setAttribute("checked",
                this.prefs.alwaysEnabled.value);
        this.prefs.alwaysEnabled.events.addListener("change", function(aEvent) {
            log("changed");
            log(self.prefs.alwaysEnabled.value);
            e("polymlext-button-alwaysEnable").setAttribute(
                    "checked", self.prefs.alwaysEnabled.value);
        });        
        e("polymlext-button-alwaysEnable").addEventListener("click",
            function() {
                self.prefs.alwaysEnabled.value =
                        !self.prefs.alwaysEnabled.value;
            }, false);
        //docs
        e("polymlext-button-docs").addEventListener("click", function() {
                gBrowser.selectedTab = gBrowser.addTab(self.links.docs);
            }, false);
        //settings
        e("polymlext-button-settings").addEventListener("click", function() {
                self.displaySettingsPage();
            }, false);        
    },
    
    displaySettingsPage : function() {
        Utils.openAndReuseOneTabPerURL(this.links.settings);
    },
    
    displayDemosPage: function() {
        Utils.openAndReuseOneTabPerURL(this.links.demos);
    },
    
    yesPoly : function(callbacks) {        
        this.callbacks = callbacks;
        
        this.bindContextMenu();
        
        //bind the page load event
        var browser = e("appcontent");
        var self = this;
        if (browser) {
            browser.addEventListener("load", function(aEvent) {
                if (aEvent.originalTarget.nodeName == "#document") {
                    var doc = aEvent.originalTarget;
                    self.callbacks.onDocumentLoad(doc);
                }
            }, true);
        }
        //bind the tab select event
        gBrowser.tabContainer.addEventListener("TabClose",
                                               this.callbacks.onTabClose,
                                               false);
        
        //bind the tab select event
        gBrowser.tabContainer.addEventListener("TabSelect",
                                               this.callbacks.onTabSelect,
                                               false);
        
        //bind the tab move event
        gBrowser.tabContainer.addEventListener("TabMove",
                                               this.callbacks.onTabMove,
                                               false);
    },
    
    setStatus : function(console) {
        if (this.console.activeConsole!=console) {
            return;
        }
        
        e("polymlext-icon-statusindicator").value = console.status.s;
        if (console.status.error) {
            e("polymlext-icon-statusindicator").style["color"] = "red";
        } else {
            e("polymlext-icon-statusindicator").style["color"] = "black";
        }
        
        //IMPROVE
        //this is fine for now, but once BrowserUI interactions start getting a
        //a bit more complex this should be refactored. Hardcoding the label
        //is not very good, also it's not very good to check the value of the
        //string as opposed to having some boolean variable for tracking the
        //enabled-to-click and enabled-already for each tab should...oops..not very clear
        if (PolyMLext.polyFound) {
            if (console.status.s=="Click to enable PolyML app") {
                //bind the click to load the app button
                e("polymlext-icon-statusindicator").addEventListener("click",
                    this.callbacks.onPolyEnable, false);
            } else {
                //remove the click to load the app button listener
                e("polymlext-icon-statusindicator").removeEventListener("click",
                    this.callbacks.onPolyEnable, false);
            }
        }
    },
    
    setGlobalStatus : function (status) {
        e("polymlext-icon-statusindicator").value = status.s;
        if (status.error) {
            e("polymlext-icon-statusindicator").style["color"] = "red";
        } else {
            e("polymlext-icon-statusindicator").style["color"] = "black";
        }
    }
};

var ConsoleUI = function(BrowserUI) {
    this.browser = BrowserUI;
    this.bindButtons();
    this.bindCommandLine();
}
ConsoleUI.prototype = {
    KEY_ENTER : 13,
    KEY_UP : 38,
    KEY_DOWN : 40,
    
    update : function(console) {
        if (this.activeConsole == console) {
            var logarea = e("polymlext-console-logarea").contentDocument;
            var annotatedContent = ""
            for (var i in this.activeConsole.content) {
                var item = this.activeConsole.content[i];
                switch (item.type) {
                    case "input":
                        annotatedContent += '<div class="polymlext-console-item-input"><pre>'+item.m+'</pre></div>';
                        break;
                    case "output":
                        annotatedContent += '<div class="polymlext-console-item-output"><pre>'+item.m+'</pre></div>';
                        break;
                    case "error":
                        annotatedContent += '<div class="polymlext-console-item-error"><pre>'+item.m+'</pre></div>';
                        break;
                }
            }
            logarea.getElementById("polymlext-console-logarea").innerHTML = annotatedContent;
            this.scrollDown();
        }
    },
    
    select : function(console) {
        this.activeConsole = console;
        PolyMLext.BrowserUI.setStatus(this.activeConsole);
        e("polymlext-icon-statusindicator").setAttribute("hidden", false);
        this.update(console);
        if (this.activeConsole.enabled) {
            if (this.activeConsole.poly.enabled) {
                if (this.activeConsole.minimized) {
                    this.hideConsole();
                } else {
                    this.showConsole();
                }
                this.setButtonColor("red");
            }
        } else {
            this.disable();
        }
    },
    
    scrollDown : function() {
        //var textbox = e("polymlext-console-logarea");
        //var ti = document.getAnonymousNodes(textbox)[0].childNodes[0];
        //ti.scrollTop = ti.scrollHeight;
        
        var iframe = e("polymlext-console-logarea");
        //wrappedJSObject
        iframe.contentDocument.defaultView.scrollTo(0, iframe.contentDocument.body.clientHeight);
    },

    clearConsole : function() {
        var logarea = e("polymlext-console-logarea").contentDocument;
        logarea.getElementById("polymlext-console-logarea").innerHTML = "";
    },
    
    toggleConsole : function(event) {
        if (this.activeConsole == null) {
            return;
        }
        if (!this.activeConsole.poly.enabled) {
            return;
        }
        if (event!=null && event.button!=0) {
            return;
        }
        if (this.activeConsole.minimized) {
            this.showConsole();
            Application.prefs.setValue(
                    "extensions.polymlext@ed.ac.uk.Console.enabledOnStartup",
                    true);
        } else {
            Application.prefs.setValue(
                "extensions.polymlext@ed.ac.uk.Console.minimizedOnStartup",
                true);
            this.hideConsole();
        }
        this.activeConsole.enabled = true;
        this.setButtonColor("red");
        this.activeConsole.minimized = !this.activeConsole.minimized;
    },
     
    //this disables the console, but keeps the activeConsole reference if it
    //were to be enabled again
    disable : function() {
        this.activeConsole.enabled = false;
        this.activeConsole.minimized = true;
        this.activeConsole.content = [];
        this.hideConsole();
        this.setButtonColor("gray");
        this.clearConsole();
    },
    
    /*
    enable : function() {
        this.activeConsole.enabled = true;
        this.activeConsole.minimized = false;
        this.showConsole();
        this.setButtonColor("red");
    },
    */
    
    //this is called when a page containing no PolyML becomes active
    off : function(console) {
        if (console==undefined || this.activeConsole == console) {
            this.activeConsole = null;
            this.hideConsole();
            this.clearConsole();
            this.setButtonColor("gray");
            e("polymlext-icon-statusindicator").setAttribute("hidden", true);
        }
    },
    
    setButtonColor : function(c) {
        if (c=="gray") {
            e("polymlext-button-console").setAttribute("src",
                    "chrome://polymlext/skin/polyml_16x16_gray.png");
        } else {
            e("polymlext-button-console").setAttribute("src",
                    "chrome://polymlext/skin/polyml_16x16.png");
        }
    },
    
    showConsole : function() {
        e("polymlext-console-box").setAttribute("collapsed", false);
        e("polymlext-console-splitter").setAttribute("collapsed", false);
        Application.prefs.setValue(
            "extensions.polymlext@ed.ac.uk.Console.minimizedOnStartup", false);
    },
    
    hideConsole : function() {
        e("polymlext-console-box").setAttribute("collapsed", true);
        e("polymlext-console-splitter").setAttribute("collapsed", true);
    },

    bindButtons : function() {
        var self = this;
        e("polymlext-button-console").addEventListener("click",
            function(event) {
                self.toggleConsole(event)
            }, false);
        //TODO: RESOLVE THE CONFUSION, the button is called 'off', but the action
        //function for this button is called 'disable', and there is also another
        //function called 'off' that does smth else..
        e("polymlext-console-button-off").addEventListener("click",
            function(event) {
                var LEFT_BUTTON = 0;
                if (event.button==LEFT_BUTTON) {
                    self.disable();
                    Application.prefs.setValue(
                        "extensions.polymlext@ed.ac.uk.Console.enabledOnStartup",
                        false);
                }
            }, false);
        e("polymlext-console-button-min").addEventListener("click",
            function(event) {
                var LEFT_BUTTON = 0;
                if (event.button==LEFT_BUTTON) {
                    self.toggleConsole();
                }
            }, false);
    },
    
    handleKeyDown : function(event) {
        //event.shiftKey
        switch (event.which) {
            case this.KEY_ENTER:
                var command = e("polymlext-console-commandline-input").value;
                e("polymlext-console-commandline-input").value = "";
                this.activeConsole.logInput(command);
                this.activeConsole.historyAdd(command);
                if (command!="") {
                    this.activeConsole.poly.sendCode(command);
                }
                break;
            case this.KEY_UP:
                e("polymlext-console-commandline-input").value =
                        this.activeConsole.historyOlder();
                break;
            case this.KEY_DOWN:
                e("polymlext-console-commandline-input").value =
                        this.activeConsole.historyNewer();
                break;
        }
    },
    
    bindCommandLine : function() {
        var self = this;
        e("polymlext-console-commandline-input").addEventListener("keydown",
            function(event) { self.handleKeyDown(event) },
            false);
    },
    
    rebindCommandLine : function() {
        this.bindCommandLine();
    }
};

}());