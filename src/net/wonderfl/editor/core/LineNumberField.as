package net.wonderfl.editor.core 
{
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	import flash.text.engine.ElementFormat;
	import flash.text.engine.FontDescription;
	import flash.text.engine.TextBlock;
	import flash.text.engine.TextElement;
	import flash.text.engine.TextLine;
	import flash.text.TextFormat;
	import flash.ui.Mouse;
	import flash.ui.MouseCursor;
	import net.wonderfl.component.core.UIComponent;;
	import net.wonderfl.editor.core.FTETextField;
	import net.wonderfl.utils.calcFontBox;
	/**
	 * ...
	 * @author kobayashi-taro
	 */
	[Event(name = 'resize', type = 'flash.events.Event')]
	public class LineNumberField extends UIComponent
	{
		private var _fte:FTETextField;
		private var _defaultTextFormat:TextFormat;
		private var _block:TextBlock;
		private var _scrollY:int = -1;
		
		public function LineNumberField($fte:FTETextField) 
		{
			_fte = $fte;
			_block = new TextBlock;
			mouseChildren = false;
			
			_defaultTextFormat = $fte.defaultTextFormat;
			_fte.addEventListener(Event.SCROLL, onScroll);
			_width = 0;
			
			addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
			addEventListener(MouseEvent.MOUSE_OVER, function ():void {
				Mouse.cursor = MouseCursor.ARROW;
			});
			
			onScroll(null);
		}
		
		
		private function mouseDown(e:MouseEvent):void 
		{
			var pos:int;
			var lineStart:int;
			var lineEnd:int;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMove);
			stage.addEventListener(MouseEvent.MOUSE_UP, mouseUp);
			
			lineStart = lineEnd = getPos();
			updateSelection();
			
			function mouseMove(e:MouseEvent):void {
				lineEnd = getPos();
				updateSelection();
			}
			function mouseUp(e:MouseEvent):void {
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, mouseMove);
				stage.removeEventListener(MouseEvent.MOUSE_UP, mouseUp);
				mouseMove(null);
			}
			function updateSelection():void {
				var s:int = lineStart;
				var e:int = lineEnd;
				if (s > e) {
					var t:int = s;
					s = e;
					e = t;
				}
				var i:int = 0;
				var selStart:int = _fte.firstPos;
				var selEnd:int;
				while (i < s) {
					selStart = _fte.text.indexOf(FTETextField.NL, selStart) + 1;
					++i;
				}
				selEnd = selStart;
				while (i <= e) {
					selEnd = _fte.text.indexOf(FTETextField.NL, selEnd) + 1;
					if (selEnd == 0) break;
					++i;
				}
				selEnd = (selEnd == 0) ? _fte.length : selEnd;
				_fte.setSelection(selStart, selEnd);
			}
			function getPos():int {
				return (mouseY / _fte.boxHeight) >> 0;
			}
		}
		
		private function onScroll(e:Event):void 
		{
			if (_scrollY != _fte.scrollY) {
				_scrollY = _fte.scrollY;
				draw();
			}
		}
		
		public function draw():void {
			var line:TextLine;
			
			while (numChildren)	removeChildAt(0);
			
			var rows:int = _fte.visibleRows;
			var start:int = _scrollY;
			var end:int = start + rows;
			var arr:Array = [];
			
			end = (end > _fte.numLines) ? _fte.numLines : end;
			
			for (var i:int = start; i <= end; ++i) 
			{
				arr[i - start] = i;
			}
			
			
			var elementFormat:ElementFormat = new ElementFormat(new FontDescription(_defaultTextFormat.font), _defaultTextFormat.size + 0, 0xffffff);
			var textElement:TextElement = new TextElement(arr.join('\n'), elementFormat);
			_block.content = textElement;
			
			var w:int = 0;
			line = _block.createTextLine(null, TextLine.MAX_LINE_WIDTH);
			while (line) {
				w = (w < line.textWidth) ? line.textWidth : w;
				addChild(line);
				line = _block.createTextLine(line, TextLine.MAX_LINE_WIDTH);
			}
			w += 4;
			i = 0;
			if (numChildren) {
				line = getChildAt(0) as TextLine;
				while (line) {
					line.x = w - line.textWidth;
					line.y = _fte.boxHeight * i++ - 2;
					line = line.nextLine;
				}
			}
			
			w += 6;
			if (_fte.x != w) {
				_width = w;
				
				dispatchEvent(new Event(Event.RESIZE));
			}
			//_height = i * _fte.boxHeight - 2;
			
			graphics.clear();
			graphics.beginFill(0);
			graphics.drawRect(0, 0, _width, _height);
			graphics.endFill();
		}
		
		
		override protected function updateSize():void 
		{
			draw();
		}
		
		public function set defaultTextFormat(value:TextFormat):void 
		{
			_defaultTextFormat = value;
		}
	}
}