package ;

import flash.display.Sprite;
import flash.display.Stage;
import flash.display.StageQuality;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.Font;
import flash.media.Sound;
import flash.media.SoundChannel;
import flash.media.SoundTransform;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.filters.DropShadowFilter;
import flash.ui.Keyboard;
import openfl.Assets;

class Tunings {
    // Pick a nice ring in HSL color space
    // to generate random colors out of.
    public static inline var colorSaturation = 0.69;
    public static inline var colorLightness = 0.69;
    public static inline var colorAlpha = 0.7;

    // Set the speed of the movement.
    // NOTE: These could be calculated by
    // percentages of the stage.
    public static inline var speedMax = 2.2;
    public static inline var speedMin = 1.4;

    public static inline var markerSlowGrowth = 21;
    public static inline var markerStartCollapse = 73;

    public static inline var glowSpeed = 0.007;

    public static inline function growthInitial(size:Float) : Float {
        return (size*(3.0/12.0));
    }

    public static inline function growthEnding(size:Float) : Float {
        return (size*(0.4/12.0));
    }

    public static inline function deflate(size:Float) : Float {
        return (size*(8.0/12.0));
    }

    public static inline function ballSize(stage:Stage) : Float {
        return Math.fround((8.0/480)
                            * Math.min(stage.stageWidth,
                                       stage.stageHeight));
    }
}

typedef RGB = {
    var r:Float;
    var g:Float;
    var b:Float;
}

typedef Hsl = {
    var h:Float;
    var s:Float;
    var l:Float;
}

class Color {
    public var r:Float;
    public var g:Float;
    public var b:Float;
    public var a:Float;

    public function new(r:Float=0, g:Float=0, b:Float=0, a:Float=0) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }

    public function set(r:Float, g:Float, b:Float, a:Float) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }

    private function hueToRgb(p:Float, q:Float, t:Float) {
        // Normalize the hue
        if (t < 0) t += 1;
        if (t > 1) t -= 1;

        if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
        if (t < 1.0/2.0) return q;
        if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
        return p;
    }

    public function setHsl(h:Float, s:Float, l:Float) {
        if (s == 0.0) {
            r = g = b = l;
        } else {
            var q = if (l < 0.5) (l * (1.0 + s)) else (l + s - l * s);
            var p = 2.0 * l - q;
            r = hueToRgb(p, q, h + 1.0/3.0);
            g = hueToRgb(p, q, h);
            b = hueToRgb(p, q, h - 1.0/3.0);
        }
    }

    public function setHslObj(hsl:Hsl) {
        setHsl(hsl.h, hsl.s, hsl.l);
    }

    public function adjustChannel(orig:Float, delta:Float) {
        var res = orig + delta;
        if (res > 1.0) {
            return 1.0;
        } else if (res < 0) {
            return 0.0;
        } else {
            return res;
        }
    }

    public function getHsl() : Hsl {
        var max = Math.max(Math.max(r, g), b);
        var min = Math.min(Math.min(r, g), b);
        var h = 0.0;
        var s = 0.0;
        var l = (max + min) / 2;
        if (max == min) {
            h = s = 0;
        } else {
            var d = max - min;
            s = if (l > 0.5) (d / (2 - max - min)) else (d / (max + min));
            if (max == r)
                h = (g - b) / d + (if (g < b) 6 else 0);
            else if (max == g)
                h = (b - r) / d + 2.0;
            else
                h = (r - g) / d + 4.0;
            h = h / 6.0;
        }
        return {h:h, s:s, l:l};
    }

    public function luminosityAdjust(delta:Float) {
        r = adjustChannel(r, delta);
        g = adjustChannel(g, delta);
        b = adjustChannel(b, delta);
    }

    public function getUInt() : UInt {
        return (Math.round(a * 255) << 24)
             | (Math.round(r * 255) << 16)
             | (Math.round(g * 255) << 8)
             | (Math.round(b * 255));
    }
}

class Utils {
    public static function random(x: Float) : Float {
        return Math.random() * x;
    }

    public static function randColor() : Color {
        var hsl = {h:Math.random(),
                   s:Tunings.colorSaturation,
                   l:Tunings.colorLightness};
        var color = new Color();
        color.setHslObj(hsl);
        return color;
    }

    public static function randomSign() : Float {
        if (Math.random() > 0.5)
            return 1;
        else
            return -1;
    }

    public static function randomDirection() : Float {
        var res = Math.random() * Tunings.speedMax * randomSign();
        if (Math.abs(res) < Tunings.speedMin) {
            if (res < 0) res = -Tunings.speedMin;
            else         res =  Tunings.speedMin;
        }
        return res;
    }
}

typedef Position = {
    var x:Float;
    var y:Float;
}

typedef Vector = {
    var dx:Float;
    var dy:Float;
}

class Ball {
    public var position:Position;
    public var size:Float;
    public var color:Color;
    public var direction:Vector;
    public var timeline:Int;
    public var exploding:Bool;

    public var growthInitial:Float;
    public var growthEnding:Float;
    public var deflate:Float;
    public var timeMarker1:Int;
    public var timeMarker2:Int;

    public function new(pos:Position, dir:Vector, color:Color, size:Float) {
        this.position = pos;
        this.size = size;
        this.color = color;
        this.direction = dir;
        
        timeline = 0;
        exploding = false;

        growthInitial = Tunings.growthInitial(size);
        growthEnding = Tunings.growthEnding(size);
        deflate = Tunings.deflate(size);
        timeMarker1 = Tunings.markerSlowGrowth;
        timeMarker2 = Tunings.markerStartCollapse;
    }

    public function setExploding() {
        exploding = true;
    }

    public function advance(app:Main) {
        var sceneWidth = app.stage.stageWidth;
        var sceneHeight = app.stage.stageHeight;
        var oldPos = position;
        position = {x: (direction.dx + oldPos.x),
                    y: (direction.dy + oldPos.y)};

        // Stage collision test
        if ((position.x > sceneWidth) || (position.x < 0)) {
            this.direction.dx = -(this.direction.dx);
        }
        if ((position.y > sceneHeight) || (position.y < 0)) {
            this.direction.dy = -(this.direction.dy);
        }

        position = {x: (direction.dx + oldPos.x),
                    y: (direction.dy + oldPos.y)};
    }

    public function grow() {
        this.timeline++;
        color.luminosityAdjust(Tunings.glowSpeed);
        if (timeline > timeMarker2) {
            size -= deflate;
        } else if (timeline > timeMarker1) {
            // This could be a little fancier but...
            size += growthEnding;
        } else {
            size += growthInitial;
        }
    }

    public function update(app:Main) {
        if (exploding) {
            grow();
            app.gameState.capture(this);
        } else {
            advance(app);
        }
    }

    public function render(canvas:Main) {
        var gfx = canvas.graphics;
        gfx.beginFill(color.getUInt(), color.a);
        gfx.drawCircle(Std.int(position.x), Std.int(position.y), Std.int(size));
        gfx.endFill();
    }
}

typedef Level = {
    var total:Int;
    var goal:Int;
}

// Construct scene off of root
// 

/**
 * Scene implements a grouping of rendering objects
 * and rendering methods that are associated to the 
 * root stage and removed from the root stage at
 * appropriate times.
 */
interface Scene {
    public function activate() : Void;
    public function deactivate() : Void;
    public function render() : Void;
}

interface GameEventListener {
    public function onGameEvent(eventId:String) : Void;
}

class SceneResults implements Scene {
    var application:Main;
    var displayString:String;

    var results:TextField;

    public function new(app:Main) {
        application = app;
        setupText();
    }

    public function setupText() {
        var stage = application.stage;
        var font = application.resources.fontBigfish;
        var textFormat = new TextFormat(font.fontName, 30, 0x00FFFFFF);
        textFormat.align = TextFormatAlign.CENTER;
        results = new TextField();
        results.defaultTextFormat = textFormat;
        results.selectable = false;
        results.width = application.stage.stageWidth;
        results.x = 0;
        results.y = (stage.stageHeight / 2) - results.height;
        results.filters = [new DropShadowFilter(2, 45, 0, 0.8, 3, 3)];
        displayString = "";
    }

    public function render() {
        application.graphics.clear();
    }

    public function onMouseClick(event:MouseEvent) {
        event.stopPropagation();

        application.setScene(application.sceneGame);
        application.gameState.finalizeLevel(application.stage);
    }

    public function activate() {
        var stage = application.stage;
        application.addEventListener(MouseEvent.CLICK, this.onMouseClick);
        application.addChild(results);

        var leveled = application.gameState.levelPassed();
        if (leveled) {
            displayString = "Hooray!  Click to continue";
        } else {
            displayString = "Click to retry";
        }
        results.text = displayString;
    }

    public function deactivate() {
        var stage = application.stage;
        application.removeEventListener(MouseEvent.CLICK, this.onMouseClick);
        application.removeChild(results);
    }
}

class SceneLevel implements Scene implements GameEventListener {
    var application:Main;
    var displayString:String;
    var hud:TextField;

    // Level transition
    var countDown:Int;
    var transitionAlpha:Float;

    public function new(app:Main) {
        application = app;
        setupHud();
    }

    public function setupHud() {
        var font = application.resources.fontBigfish;
        var textFormat = new TextFormat(font.fontName, 20, 0x00FFFFFF);
        hud = new TextField();
        hud.defaultTextFormat = textFormat;
        hud.selectable = false;
        hud.width = application.stage.stageWidth;
        hud.height = 200;
        hud.x = 0;
        hud.y = 0;
        hud.filters = [new DropShadowFilter(2, 45, 0, 0.8, 3, 3)];
        displayString = "";
    }

    public function onMouseClick(event:MouseEvent) {
        var position = {x:event.stageX, y:event.stageY};
        application.gameState.startExplosion(application.stage, position);
    }

    public function onKeyDown(event:KeyboardEvent) {
        var gs = application.gameState;
        switch(event.keyCode) {
        case Keyboard.SPACE:
            if (!gs.isSeeded)
                gs.initLevel(application.stage);
        }
    }

    public function updateHud() {
        // TextField.text assignment is expensive on linux
        // Build out the string and compare and only update
        // if different
        var gs = application.gameState;
        var string = "Stage: " + (gs.currentLevel+1) + "  " +
                     "Score: " + gs.getScore() + "  " +
                     "Goal: " + gs.levels[gs.currentLevel].goal + "  ";
        if (string != displayString) {
            displayString = string;
            hud.text = displayString;
        }
    }

    public function render() {
        var gfx = application.graphics;
        var gs = application.gameState;

        gs.update(application);

        updateHud();
        gfx.clear();
        for (ball in gs.objects) {
            ball.render(application);
        }

        if (gs.levelEnded) {
            // We are in a transition period
            var stage = application.stage;
            transitionAlpha = (countDown) / 30.0;
            --countDown;
            gfx.beginFill(0x00FFFFFF, 1.0 - transitionAlpha);
            gfx.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
            gfx.endFill();

            if (countDown == 0) {
                application.setScene(application.sceneResults);
            }
        }
    }

    public function onGameEvent(eventId:String) {
        if (eventId == "levelEnded") {
            countDown = 30;
            transitionAlpha;
        }
    }

    public function activate() {
        var gs = application.gameState;
        gs.gameEvent.addListener(this);
        application.addChild(hud);
        hookEvents();
    }

    public function deactivate() {
        var gs = application.gameState;
        gs.gameEvent.removeListener(this);
        application.removeChild(hud);
        unhookEvents();
    }

    public function hookEvents() {
        var stage = application.stage;
        stage.addEventListener(MouseEvent.CLICK, this.onMouseClick);
        stage.addEventListener(KeyboardEvent.KEY_DOWN, this.onKeyDown);
    }

    public function unhookEvents() {
        var stage = application.stage;
        stage.removeEventListener(MouseEvent.CLICK, this.onMouseClick);
        stage.removeEventListener(KeyboardEvent.KEY_DOWN, this.onKeyDown);
    }
}

class GameEvent {
    var listeners:Array<GameEventListener>;

    public function new() {
        listeners = new Array<GameEventListener>();
    }

    public function addListener(listener:GameEventListener) {
        listeners.push(listener);
    }

    public function removeListener(listener:GameEventListener) {
        listeners.remove(listener);
    }

    public function trigger(eventId:String) {
        for (listener in listeners) {
            listener.onGameEvent(eventId);
        }
    }
}

class GameState {
    public var objects:Array<Ball>;
    public var moving:Array<Ball>;
    public var exploding:Array<Ball>;
    public var currentLevel:Int;
    public var levels:Array<Level>;
    public var isSeeded:Bool;
    public var levelEnded:Bool;

    public var gameEvent:GameEvent;

    public var resources:Resources;

    public function new(res:Resources) {
    	resources = res;
        initLevels();
        gameEvent = new GameEvent();
    }

    public function initLevels() {
        levels = new Array<Level>();
        levels.push({total: 5, goal: 1});
        levels.push({total: 8, goal: 3});
        levels.push({total:15, goal: 5});
        levels.push({total:28, goal: 10});
        levels.push({total:35, goal: 19});
        levels.push({total:41, goal: 32});
        levels.push({total:60, goal: 55});
        currentLevel = 0;
    }

    public function getScore() {
        return levels[currentLevel].total - moving.length;
    }

    public function getDistance(pos1:Position, pos2:Position) {
        return Math.sqrt(  Math.pow(pos2.x - pos1.x, 2)
                         + Math.pow(pos2.y - pos1.y, 2));
    }

    public function capture(src:Ball) {
        var capturedSet = new Array<Ball>();
        for (mover in moving) {
            var dist = getDistance(src.position, mover.position);
            if (dist-(mover.size) < src.size) {
                capturedSet.push(mover);
            }
        }
        for (captured in capturedSet) {
            setExploding(captured);
        }
    }

    public function initLevel(stage:Stage) {
        var level = levels[currentLevel];
        objects = new Array<Ball>();
        moving = new Array<Ball>();
        exploding = new Array<Ball>();
        for (i in 0...level.total) {
            var position = {x:Math.random()*stage.stageWidth,
                            y:Math.random()*stage.stageHeight};
            var direction = {dx:Utils.randomDirection(),
                             dy:Utils.randomDirection()};
            var color = Utils.randColor();
            color.a = Tunings.colorAlpha;
            var size = Tunings.ballSize(stage);
            var newBall = new Ball(position, direction, color, size);
            objects.push(newBall);
            moving.push(newBall);
        }
        isSeeded = false;
        levelEnded = false;
    }

    public function update(app:Main) {
        if (levelEnded)
            return;

        for (ball in objects) {
            ball.update(app);
        }

        var saveList = new Array<Ball>();
        if (isSeeded) {
            for (ball in exploding) {
                if (ball.size <= 0) {
                    objects.remove(ball);
                    exploding.remove(ball);
                }
            }
            if (exploding.length == 0) {
                setLevelEnded();
            }
        }
    }

    public function levelPassed() {
        var score = getScore();
        if (score >= levels[currentLevel].goal) {
            return true;
        } else {
            return false;
        }
    }

    public function setLevelEnded() {
        if (levelPassed()) {
            gameEvent.trigger("preTransLevelPassed");
        } else {
            gameEvent.trigger("preTransLevelFailed");
        }
        levelEnded = true;
        gameEvent.trigger("levelEnded");
    }

    public function finalizeLevel(stage) {
        if (levelPassed()) {
            currentLevel++;
            if (currentLevel == levels.length)
                currentLevel = 0;
        }
        initLevel(stage);
    }

    public function setExploding(captured:Ball) {
        moving.remove(captured);
        exploding.push(captured);
        captured.setExploding();
        gameEvent.trigger("ballCaptured");
	resources.playChime();
    }
    
    public function startExplosion(stage:Stage, pos:Position) {
        if (!isSeeded) {
            var size = Tunings.ballSize(stage);
            var color = new Color(0.5, 0.5, 0.5, Tunings.colorAlpha);
            var dir = {dx:0.0, dy:0.0};
            var seed = new Ball(pos, dir, color, size);
            objects.push(seed);
            exploding.push(seed);
            seed.setExploding();
            isSeeded = true;
        }
    }
}

class Resources {
    public var fontBigfish:Font;

    public var sndSuccess:Sound;
    public var sndFail:Sound;
    public var sndChime1:Sound;
    public var sndChime2:Sound;
    public var sndChime3:Sound;
    public var sndChime4:Sound;
    public var sndChime5:Sound;
    public var sndSong:Sound;
    public var chanSong:SoundChannel;

    public var sndChimes:Array<Sound>;
    public var sndLevelsSfx:SoundTransform;
    public var sndLevelsMusic:SoundTransform;

    public function new() {
        fontBigfish = Assets.getFont("fonts/Bigfish.ttf");
        sndSuccess = Assets.getSound("success");
        sndFail = Assets.getSound("fail");
        sndChime1 = Assets.getSound("chime1");
        sndChime2 = Assets.getSound("chime2");
        sndChime3 = Assets.getSound("chime3");
        sndChime4 = Assets.getSound("chime4");
        sndChime5 = Assets.getSound("chime5");
        sndSong = Assets.getMusic("song");
        sndChimes = new Array<Sound>();
        sndChimes.push(sndChime1);
        sndChimes.push(sndChime2);
        sndChimes.push(sndChime3);
        sndChimes.push(sndChime4);
        sndChimes.push(sndChime5);

        sndLevelsSfx = new SoundTransform(0.6);
        sndLevelsMusic = new SoundTransform(0.5);
    }

    public function startBgMusic() {
        chanSong = sndSong.play(0, 0, sndLevelsMusic);
    }

    public function playChime() {
        var i = Math.round(Math.random() * (sndChimes.length - 1));
        sndChimes[i].play(0, 0, sndLevelsSfx);
    }
}

class Main extends Sprite {
    static inline var GS_GAME = 0;
    static inline var GS_ENDING = 1;
    static inline var GS_RESULTS = 2;
    static inline var GS_PAUSED = 3;
    static inline var GS_MENU = 4;

    public var gameScene:Int;
    public var gameState:GameState;
    public var sceneGame:SceneLevel;
    public var sceneResults:SceneResults;
    public var resources:Resources;

    var currentScene:Scene;

    public function new() {
        super();
        resources = new Resources();
        gameState = new GameState(resources);
        sceneGame = new SceneLevel(this);
        sceneResults = new SceneResults(this);
        // TODO: Restore last game
        gameState.initLevel(stage);
        gameScene = GS_GAME;
        currentScene = sceneGame;
        sceneGame.activate();
        hookEvents();
        // resources.startBgMusic();
    }

    public function hookEvents() {
        addEventListener(Event.ENTER_FRAME, this.onEnterFrame);
    }

    public function setScene(scene:Scene) {
        currentScene.deactivate();
        currentScene = scene;
        currentScene.activate();
    }

    public function onEnterFrame(event:Event) {
        //
        // Main game loop
        //
        currentScene.render();
    }
}
