package net.wonderfl.editor.manager
{
	import flash.display.DisplayObject;
	import flash.display.InteractiveObject;
	import flash.events.ContextMenuEvent;
	import flash.events.Event;
	import flash.net.navigateToURL;
	import flash.net.URLRequest;
	import flash.system.Capabilities;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import net.wonderfl.editor.IEditor;
	/**
	 * ...
	 * @author kobayashi-taro
	 */
	public class ContextMenuBuilder
	{
		private static function get COPY():String { return  'Copy (C-c)'.replace(C, replacement); }
		private static function get CUT():String { return  'Cut (C-x)'.replace(C, replacement); }
		private static function get UNDO():String { return  'Undo (C-z)'.replace(C, replacement); }
		private static function get REDO():String { return  'Redo (C-y)'.replace(C, replacement); }
		private static function get PASTE():String { return  'Paste (C-v)'.replace(C, replacement); }
		private static function get SELECT_ALL():String { return  'Select All (C-a)'.replace(C, replacement); }
		private static function get SAVE():String { return  'Save (C-s)'.replace(C, replacement); }
		private static function get AUTO_BRACE_INSERTION():String { return <>Auto Brace Insertion ({EditManager.autoBraceInsertion ? "enabled" : "disabled"})</>; }
		private static const C:RegExp = /\(C-(\w)\)/;
		private static const MINI_BUILDER:String = 'MiniBuilder';
		private static var _this:ContextMenuBuilder;
		private var _editor:IEditor;
		private var _editable:Boolean;
		private var _menu:ContextMenu;
		private var _itemSelectAll:ContextMenuItem;
		private var _itemCut:ContextMenuItem;
		private var _itemCopy:ContextMenuItem;
		private var _itemUndo:ContextMenuItem;
		private var _itemRedo:ContextMenuItem;
		private var _itemBraceInsertion:ContextMenuItem;
		
		private static function replacement($match:String, $key:String, $index:int, $str:String):String {
			return <>({(Capabilities.os.indexOf('Mac') != -1) ? "Cmd" : "Ctrl"}-{$key})</>;
		}
		
		public static function getInstance():ContextMenuBuilder { return (_this ||= new ContextMenuBuilder); }
		public function buildMenu($menuContainer:InteractiveObject, $editor:IEditor, $editable:Boolean = false):void
		{
			_menu = new ContextMenu;
			_menu.hideBuiltInItems();
			_editor = $editor;
			_editable = $editable;
			
			var menuCaptions:Array = [COPY, SELECT_ALL, SAVE, MINI_BUILDER];
			if ($editable) {
				menuCaptions.splice(1, 0, CUT, PASTE);
				menuCaptions.splice(4, 0, UNDO, REDO);
				menuCaptions.splice(8, 0, AUTO_BRACE_INSERTION);
			}
			
			_menu.customItems = menuCaptions.map(
				function ($caption:String, $index:int, $arr:Array):ContextMenuItem {
					var item:ContextMenuItem = new ContextMenuItem($caption, $caption == MINI_BUILDER || $caption == SAVE || $caption == UNDO || $caption == AUTO_BRACE_INSERTION);
					item.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, onMenuItemSelected);
					
					switch($caption) {
					case COPY:
						_itemCopy = item;
						break;
					case CUT:
						_itemCut = item;
						break;
					case SELECT_ALL:
						_itemSelectAll = item;
						break;
					case UNDO:
						_itemUndo = item;
						break;
					case REDO:
						_itemRedo = item;
						break;
					case AUTO_BRACE_INSERTION:
						_itemBraceInsertion = item;
						break;
					case PASTE:
						item.enabled = false; // cannot paste from context menu due to the security problem
						break;
					}
					
					return item;
				}
			);
			_menu.addEventListener(ContextMenuEvent.MENU_SELECT, _menuSelect);
			$menuContainer.contextMenu = _menu;
		}
		
		private function _menuSelect(e:ContextMenuEvent):void {
			var hasSelectionArea:Boolean = (_editor.selectionBeginIndex != _editor.selectionEndIndex);
			_itemCopy.enabled = hasSelectionArea;
			_itemSelectAll.enabled = (_editor.selectionBeginIndex > 0 || _editor.selectionEndIndex < _editor.text.length - 1);
			
			if (_editable) {
				_itemCut.enabled = hasSelectionArea;
				_itemUndo.enabled = (HistoryManager.getInstance().undoStack != null);
				_itemRedo.enabled = (HistoryManager.getInstance().redoStack != null);
				_itemBraceInsertion.caption = AUTO_BRACE_INSERTION;
			}
		}
		
		private function onMenuItemSelected(e:ContextMenuEvent):void 
		{
			switch (e.currentTarget.caption) {
			case COPY :
				_editor.copy();
				break;
			case CUT:
				_editor.cut();
				break;
			//case PASTE:
				//_editor.paste();
				//break;
			case SELECT_ALL :
				_editor.selectAll();
				break;
			case SAVE : 
				_editor.saveCode();
				break;
			case AUTO_BRACE_INSERTION:
				LocalSettingManager.getInstance().autoBraceInsertion = !EditManager.autoBraceInsertion;
				break;
			case UNDO:
				HistoryManager.getInstance().undo();
				break;
			case REDO:
				HistoryManager.getInstance().redo();
				break;
			case MINI_BUILDER :
				navigateToURL(new URLRequest('http://code.google.com/p/minibuilder/'), '_self');
				break;
			}
		}
	}

}