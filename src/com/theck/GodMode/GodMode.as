/*
* ...
* @author theck
*/

import com.Utils.Archive;
import com.GameInterface.Game.Character;
import com.Utils.ID32;
import com.Utils.Text;
import mx.utils.Delegate;
import flash.geom.Point;
import com.theck.GodMode.ConfigManager;
import com.theck.Utils.Common;
import com.GameInterface.Inventory;
import com.GameInterface.InventoryItem;
import com.Utils.GlobalSignal;

class com.theck.GodMode.GodMode 
{
	static var debugMode:Boolean = false;
	
	// Version
	static var version:String = "0.1";
	
	// Signals
	//static var SubtitleSignal:Signal;

	// GUI
	private var m_swfRoot:MovieClip;	
	private var clip:MovieClip;	
	private var m_Indicator:TextField;	
	private var m_pos:flash.geom.Point;
	private var guiEditThrottle:Boolean = true;
	
	static var DEFAULT_COLOR:Number = 0xFFCC00;
	static var DEFAULT_TEXT:String = "GM";
	
	private var m_player:Character;
	private var m_weaponInventory:Inventory;
	private var auto_loader_counter:Number = 0;
	
	// Config
	private var Config:ConfigManager;
	
	
	
	//////////////////////////////////////////////////////////
	// Constructor and Mod Management
	//////////////////////////////////////////////////////////
	
	
	public function GodMode(swfRoot:MovieClip){
		
		m_swfRoot = swfRoot;
		
		// Create Config
		Config = new ConfigManager();
		Config.NewSetting("fontsize", 30, "");
		Config.NewSetting("text", DEFAULT_TEXT, "");
		Config.NewSetting("color", DEFAULT_COLOR, "");
		
		// Create GUI
		clip = m_swfRoot.createEmptyMovieClip("GodMode", m_swfRoot.getNextHighestDepth());
		
		clip._x = Stage.width /  2;
		clip._y = Stage.height / 2;
		
		Config.NewSetting("position", new Point(clip._x, clip._y), "");
		
		// Create Player and Weapon inventory variables
		m_player = Character.GetClientCharacter();
		m_weaponInventory = new Inventory(new ID32(_global.Enums.InvType.e_Type_GC_WeaponContainer, Character.GetClientCharacter().GetID().GetInstance()));
	
	}

	public function Load(){
		com.GameInterface.UtilsBase.PrintChatText("GodMode v" + version + " Loaded");
		
		// connect signals
		GlobalSignal.SignalSetGUIEditMode.Connect(GUIEdit, this);	
		Config.SignalValueChanged.Connect(SettingChanged, this);
		
		// first GUIEdit call to fix locations
		GUIEdit(false);
	}

	public function Unload(){
		
		// disconnect signals
		GlobalSignal.SignalSetGUIEditMode.Disconnect(GUIEdit, this);
		Config.SignalValueChanged.Disconnect(SettingChanged, this);
	}
	
	public function Activate(config:Archive){
		Debug("Activate()");
		
		Config.LoadConfig(config);
		
		// Create text field and fix visibility
		if ( !m_Indicator ) {
			CreateTextField();
		}		
		SetVisible(m_Indicator, false);
		
		// move clip to location
		SetPosition(Config.GetValue("position") );
		
		// run once to connect signals on load if Rifle is equipped
		OnWeaponChange();
		m_weaponInventory.SignalItemAdded.Connect(OnWeaponChange, this);
	}

	public function Deactivate():Archive{
		m_weaponInventory.SignalItemAdded.Disconnect(OnWeaponChange, this);
		var config = new Archive();
		config = Config.SaveConfig();
		return config;
	}
	
	
	//////////////////////////////////////////////////////////
	// Text Field Controls
	//////////////////////////////////////////////////////////

	
	private function CreateTextField() {
		Debug("CTF called");
		var m_fontSize:Number = Config.GetValue("fontsize");
		var m_text:String = Config.GetValue("text");		
		var m_color:Number = Config.GetValue("color");
		
		var textFormat:TextFormat = new TextFormat("_StandardFont", m_fontSize, m_color, true);
		textFormat.align = "center";
		
		var extents:Object = Text.GetTextExtent(m_text, textFormat, clip);
		var height:Number = Math.ceil( extents.height * 1.10 );
		var width:Number = Math.ceil( extents.width * 1.10 );
		
		
		m_Indicator = clip.createTextField("GodMode_Indicator", clip.getNextHighestDepth(), 0, 0, width, height);
		m_Indicator.setNewTextFormat(textFormat);
		
		InitializeTextField(m_Indicator);
		
		SetText(m_Indicator, m_text );
		
		GUIEdit(false);
	}
	
	private function DestroyTextField() {
		Debug("DTF called");
		m_Indicator.removeTextField();
	}
	
	private function ReCreateTextField() {
		Debug("RCTF called");
		DestroyTextField();
		CreateTextField();
	}
		
	private function InitializeTextField(field:TextField) {
		field.background = true;
		field.backgroundColor = 0x000000;
		field.autoSize = "center";
		field.textColor = Config.GetValue("color", DEFAULT_COLOR);		
		field._alpha = 90;
	}
	
	private function SetText(field:TextField, textString:String) {
		field.text = textString;		
	}
	
	private function SetVisible(field:TextField, state:Boolean) {
		field._visible = state;
	}
	
	private function SetTextColor(color:Number) {
		m_Indicator.textColor = color;
	}
	
	private function ClearIndicator() {
		Debug("ClearIndicator");
		SetVisible(m_Indicator, false);
	}
	
	private function SetPosition(pos:Point) {
		
		// sanitize inputs - this fixes a bug where someone changes screen resolution and suddenly the field is off the visible screen
		//Debug("pos.x: " + pos.x + "  pos.y: " + pos.y, debugMode);
		if ( pos.x > Stage.width || pos.x < 0 ) { pos.x = Stage.width / 2; }
		if ( pos.y > Stage.height || pos.y < 0 ) { pos.y = Stage.height / 2; }
		
		clip._x = pos.x;
		clip._y = pos.y;
	}
	
	private function GetPosition() {
		var pos:Point = new Point(clip._x, clip._y);
		Debug("GetPos: x: " + pos.x + "  y: " + pos.y, debugMode);
		return pos;
	}
	
	public function EnableInteraction(state:Boolean) {
		clip.hitTestDisable = !state;
	}
	
	public function ToggleBackground(flag:Boolean) {
		m_Indicator.background = flag;
	}
	
	
	//////////////////////////////////////////////////////////
	//  GUI functions
	//////////////////////////////////////////////////////////
	
	
	public function GUIEdit(state:Boolean) {
		//Debug("GUIEdit() called with argument: " + state);
		ToggleBackground(state);
		EnableInteraction(state);
		SetVisible(m_Indicator, state);
		if (state) {
			clip.onPress = Delegate.create(this, WarningStartDrag);
			clip.onRelease = Delegate.create(this, WarningStopDrag);
			//SetText(m_Indicator, "Move Me");
			SetVisible(m_Indicator, true);
			
			// set throttle variable - this prevents extra spam when the game calls GuiEdit event with false argument, which it seems to like to do ALL THE DAMN TIME
			guiEditThrottle = true;
		}
		else if guiEditThrottle {
			clip.stopDrag();
			clip.onPress = undefined;
			clip.onRelease = undefined;
			SetText(m_Indicator, Config.GetValue("text", DEFAULT_TEXT));
			SetVisible(m_Indicator, false);
			
			// set throttle variable
			guiEditThrottle = false;
			setTimeout(Delegate.create(this, ResetGuiEditThrottle), 100);
		}
	}
	
	public function WarningStartDrag() {
		//Debug("WarningStartDrag called");
        clip.startDrag();
    }

    public function WarningStopDrag() {
		//Debug("WarningStopDrag called");
        clip.stopDrag();
		
		// grab position for config storage on Deactivate()
        m_pos = Common.getOnScreen(clip); 
        Config.SetValue("position", m_pos ); 
		
		Debug("WarningStopDrag: x: " + m_pos.x + "  y: " + m_pos.y);
    }
	
	private function ResetGuiEditThrottle() {
		guiEditThrottle = true;
	}
	
	
	//////////////////////////////////////////////////////////
	// Core Logic
	//////////////////////////////////////////////////////////
	
	
	
	private function UpdateDisplay() {
		
		SetVisible(m_Indicator, (auto_loader_counter > 0 ) );
	}
	
		private function IsRifleEquipped():Boolean {
		// check which slot contains that weapon
		var main_hand_item:InventoryItem = m_weaponInventory.GetItemAt(_global.Enums.ItemEquipLocation.e_Wear_First_WeaponSlot);
		var off_hand_item:InventoryItem = m_weaponInventory.GetItemAt(_global.Enums.ItemEquipLocation.e_Wear_Second_WeaponSlot);
		
		return ( main_hand_item.m_Type == 524608 || off_hand_item.m_Type == 524608 ) 
	}
	
	private function AutoLoaderChecker(buffId:Number) {
		if ( buffId == 9257112 ) {
			auto_loader_counter++;
			UpdateDisplay();
			Debug("God Mode Enabled - proc " + auto_loader_counter);
		}
	}
	
	private function CombatMonitor(state:Boolean) {
		if ( ! state ) {
			auto_loader_counter = 0;
			Debug("Left Combat - Auto Loader Counter reset");
			UpdateDisplay();
		}		
	}
	
	//////////////////////////////////////////////////////////
	// Signal Handling
	//////////////////////////////////////////////////////////
	
	private function OnWeaponChange() {
		//Debug("OnWeaponChange");
		//Debug("Rifle is " + IsRifleEquipped() );
		if IsRifleEquipped() {
			// connect signals
			m_player.SignalToggleCombat.Connect(CombatMonitor, this);
			m_player.SignalInvisibleBuffAdded.Connect(AutoLoaderChecker, this);
		}
		else {
			// disconnect signals
			m_player.SignalToggleCombat.Disconnect(CombatMonitor, this);
			m_player.SignalInvisibleBuffAdded.Disconnect(AutoLoaderChecker, this);
		}
	}
	
	private function SettingChanged(key:String) {
		Debug("SettingsChanged, key: " + key);
		if ( key != "position" ) {
			// for when settings are updated. Create bar
			ReCreateTextField();
			
			// Move clip to location
			SetPosition( Config.GetValue("position") );
		}
	}
	
	//////////////////////////////////////////////////////////
	// Debugging
	//////////////////////////////////////////////////////////
	
	private function Debug(text:String) {
		if debugMode { com.GameInterface.UtilsBase.PrintChatText("GM:" + text ); }
	}
	
}