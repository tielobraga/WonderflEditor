﻿package  
{
	import flash.display.Bitmap;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.ContextMenuEvent;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.external.ExternalInterface;
	import flash.net.navigateToURL;
	import flash.net.URLRequest;
	import flash.system.Capabilities;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	import jp.psyark.utils.CodeUtil;
	import net.wonderfl.chat.Chat;
	import net.wonderfl.chat.ChatButton;
	import net.wonderfl.chat.ChatClient;
	import net.wonderfl.editor.AS3Viewer;
	import net.wonderfl.component.core.UIComponent;;
	import net.wonderfl.editor.livecoding.LiveCoding;
	import net.wonderfl.editor.livecoding.LiveCodingEvent;
	import net.wonderfl.editor.livecoding.LiveCodingSettings;
	import net.wonderfl.editor.livecoding.SocketBroadCaster;
	import net.wonderfl.editor.livecoding.ViewerInfoPanel;
	import net.wonderfl.editor.manager.ContextMenuBuilder;
	import org.libspark.ui.SWFWheel;
	/**
	 * ...
	 * @author kobayashi-taro
	 */
	public class WonderflViewer extends UIComponent
	{
		private static const TICK:int = 33;
		private const CHAT_BUTTON_MIN_WIDTH:int = 80;
		
		private var _viewer:AS3Viewer;
		private var broadcaster:SocketBroadCaster = new SocketBroadCaster;
		private var _source:String ='';
		private var _commandList:Array = [];
		private var _executer:Sprite = new Sprite;
		private var _parseTime:int;
		private var _setInitialCodeForLiveCoding:Boolean = false;
		private var _isLive:Boolean = false;
		private var _infoPanel:ViewerInfoPanel;
		private var _ignoreSelection:Boolean;
		private var _prevText:String;
		private var _selectionObject:Object;
		private var _client:ChatClient;
		private var _chatButton:ChatButton;
		private var _chat:Chat;
		
		public function WonderflViewer() 
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init(e:Event):void {
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			_parseTime = getTimer();
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			stage.addEventListener(Event.RESIZE, onResize);
			SWFWheel.initialize(stage);
			SWFWheel.browserScroll = false;
			
			focusRect = null;
			
			_viewer = new AS3Viewer;
			_viewer.addEventListener(Event.COMPLETE, onColoringComplete);
			addChild(_viewer);
			
			if (loaderInfo.parameters)
				LiveCodingSettings.setUpParameters(loaderInfo.parameters);
			
			broadcaster.addEventListener(Event.CONNECT, function connect():void {
				broadcaster.join(LiveCodingSettings.room, LiveCodingSettings.ticket);
			});
			broadcaster.addEventListener(LiveCodingEvent.JOINED, startListening);
			broadcaster.addEventListener(LiveCodingEvent.RELAYED, onRelayed);
			
			if (LiveCodingSettings.server && LiveCodingSettings.port) {
				broadcaster.connect(LiveCodingSettings.server, LiveCodingSettings.port);
				_setInitialCodeForLiveCoding = true;
				
				
				_client = new ChatClient;
				_client.init(root.loaderInfo.parameters);
				
				_chatButton = new ChatButton;
				var duration:int = 300;
				var startTime:int;
				var tweening:Boolean = false;
				var buttonXTo:int, buttonXFrom:int, chatXTo:int, chatXFrom:int;
				const LEFT:uint = _width - 288;
				_chatButton.x = _width - CHAT_BUTTON_MIN_WIDTH;
				
				_chatButton.addEventListener(MouseEvent.CLICK, function ():void {
					if (tweening) return;
					
					tweening = true;
					_chatButton.toggle();
					if (_chatButton.isOpen()) {
						buttonXTo = chatXTo = _width - 288;
						buttonXFrom = _width - CHAT_BUTTON_MIN_WIDTH;
						chatXFrom = _width;
					} else {
						buttonXFrom = chatXFrom = _width - 288;
						buttonXTo = _width - CHAT_BUTTON_MIN_WIDTH;
						chatXTo = _width;
						updateSize();
					}
					
					startTime = getTimer();
					addEventListener(Event.ENTER_FRAME, tweener);
				});
			}
			
			if (ExternalInterface.available) {
				var code:String = ExternalInterface.call("Wonderfl.Codepage.get_initial_code");
				_source = code || "";
				_viewer.text = _source;
 			}
			
			if (_setInitialCodeForLiveCoding) {
				addEventListener(Event.ENTER_FRAME, setupInitialCode);
				_setInitialCodeForLiveCoding = false;
			}
			
			ContextMenuBuilder.getInstance().buildMenu(this, _viewer);
			
			
			function tweener(e:Event):void {
				var time:int = getTimer() - startTime;
				
				if (time > duration) {
					_chatButton.x = buttonXTo; _chat.x = chatXTo;
					removeEventListener(Event.ENTER_FRAME, tweener);
					tweening = false;
					updateSize();
					return;
				}
				
				var t:Number = time / duration;
				var u:Number;
				t = t * (2 - t);
				u = 1 - t;
				
				_chatButton.x = t * buttonXTo + u * buttonXFrom;
				_chat.x = t * chatXTo + u * chatXFrom;
			}
			
			if (_client) {
				_chat = new Chat(_client);
				_chat.x = _width - 288;
				_chat.y = 20;
				addChild(_chat);
				
				addChild(_chatButton);
				_chatButton.setSize(288, 20);
			}
			
			stage.dispatchEvent(new Event(Event.RESIZE));
		}
		
		private function onColoringComplete(e:Event):void 
		{
			if (_selectionObject)
				onSetSelection(_selectionObject.index, _selectionObject.index);
				
			_selectionObject = null;
		}
		
		private function setupInitialCode(e:Event):void 
		{
			if (_commandList.length) {
				var t:int = getTimer();
				var command:Object;
				
				while (getTimer() - t < TICK) {
					if (_commandList.length == 0) break;
					
					command = _commandList.shift();
					if (command.method == LiveCoding.SEND_CURRENT_TEXT || command.method == LiveCoding.REPLACE_TEXT)
						command.method.apply(null, command.args);
				}
			} else {
				if (_setInitialCodeForLiveCoding) {
					removeEventListener(Event.ENTER_FRAME, setupInitialCode);
					_executer.addEventListener(Event.ENTER_FRAME, execute);
					_viewer.onChange(null);
				}
			}
		}
		
		private function onResize(e:Event):void 
		{
			var w:int = stage.stageWidth;
			var h:int = stage.stageHeight;
			var size:Array;
			if (ExternalInterface.available) {
				size = ExternalInterface.call("Wonderfl.Codepage.get_stage_size");
				if (size) {
					w = size[0];
					h = size[1];
				}
			}
			
			setSize(w, h);
		}
		
		override protected function updateSize():void 
		{
			_viewer.width = _width;
			if (_isLive) {
				_infoPanel.width = _width - 15 - (_width - _chatButton.x);
				_viewer.y = _infoPanel.height;
				_viewer.height = height - _infoPanel.height;
			} else {
				_viewer.y = 0;
				_viewer.height = _height;
			}
			
			
			if (_chatButton && _chatButton.isOpen()) {
				_viewer.setSize(_width - 288, _height);
			} else {
				_viewer.setSize(_width, _height);
				
			}
			
			if (!_chat) return;
			
			if (_chatButton.isOpen()) {
				_chat.x = _width - 288;
				_chatButton.x = _width -288;
			} else {
				_chatButton.x = _width - CHAT_BUTTON_MIN_WIDTH;
				_chat.x = _width;
			}
			_chat.setSize(288, _height - 20);
			
		}
		
		private function onRelayed(e:LiveCodingEvent):void 
		{
			if (!_isLive) {
				restart();
			}
			
			var method:Function;
			switch (e.data.command) {
			case LiveCoding.REPLACE_TEXT:
				method = onReplaceText;
				break;
			case LiveCoding.SET_SELECTION:
				method = onSetSelection;
				break;
			case LiveCoding.SEND_CURRENT_TEXT:
				method = onSendCurrentText;
				break;
			case LiveCoding.SWF_RELOADED:
				method = onSWFReloaded;
				break;
			case LiveCoding.CLOSED:
				method = onClosed;
				break;
			case LiveCoding.SCROLL_V:
				method = onScrollV;
				break;
			case LiveCoding.SCROLL_H:
				method = onScrollH;
				break;
			}
			
			if (method != null) {
				var args:Array = e.data.args;
				_commandList[_commandList.length] = {
					method : method,
					args : args
				}
			}
		}
		
		private function onScrollH($scrollH:int):void
		{
			if (_infoPanel.isSync) _viewer.scrollH = $scrollH;
		}
		
		private function onScrollV($scrollV:int):void
		{
			if (_infoPanel.isSync) _viewer.scrollY = $scrollV;
		}
		
		private function onClosed():void
		{
			trace('on closed');
			_infoPanel.stop();
			if (_infoPanel.parent) _infoPanel.parent.removeChild(_infoPanel);
			_isLive = false;
			updateSize();
		}
		
		private function restart():void {
			trace('restart');
			addChild(_infoPanel);
			addChild(_chat);
			addChild(_chatButton);
			_infoPanel.restart();
			_isLive = true;
			updateSize();
		}
		
		private function onSWFReloaded():void
		{
			if (ExternalInterface.available)
				ExternalInterface.call('Wonderfl.Codepage.reload_swf');
		}
		
		private function startListening(e:LiveCodingEvent):void 
		{
			_isLive = true;
			
			addChild(_infoPanel = new ViewerInfoPanel);
			addChild(_chat);
			addChild(_chatButton);
			_infoPanel.elapsed_time = e.data ? e.data.elapsed_time : 0;
			broadcaster.addEventListener(LiveCodingEvent.MEMBERS_UPDATED, _infoPanel.onMemberUpdate);
			updateSize();
			
			setTimeout(function ():void {
				_setInitialCodeForLiveCoding = true;
			}, 1000);
		}
		
		private function execute(e:Event):void 
		{
			if (_commandList.length) {
				var t:int = getTimer();
				var command:Object;
				
				while (getTimer() - t < TICK) {
					if (_commandList.length == 0) return;
					
					command = _commandList.shift();
					command.method.apply(null, command.args);
				}
			}
		}

		
		private function substring($begin:int, $end:int = 0x7fffffff):String {
			var str:String = _source.substring($begin, $end);
			
			return (str) ? str : '';
		}
		
		
		private function onReplaceText($beginIndex:int, $endIndex:int, $newText:String):void 
		{
			if ($beginIndex == $endIndex && $newText.length == 0) return;
			
			_viewer.slowDownParser();
			_source = _source.substring(0, $beginIndex) + $newText + substring($endIndex);
			//_viewer.text = _source;
			_viewer.onReplaceText($beginIndex, $endIndex, $newText);
			_selectionObject = {
				index : $endIndex + $newText.length
			}
			_viewer.updateLineNumbers();
		}
		
		private function onSetSelection($selectionBeginIndex:int, $selectionEndIndex:int):void
		{
			if (_viewer.selectionBeginIndex == $selectionBeginIndex && _viewer.selectionEndIndex == $selectionEndIndex)
				return;
			
			_ignoreSelection = false;
			_viewer.onSetSelection($selectionBeginIndex, $selectionEndIndex);
			_selectionObject = {
				index : $selectionEndIndex
			};
		}
		
		private function onSendCurrentText($text:String):void 
		{
			_viewer.text = _source = $text;
		}		
	}
}