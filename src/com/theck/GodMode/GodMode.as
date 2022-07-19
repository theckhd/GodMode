/*
* ...
* @author theck
*/

import com.GameInterface.WaypointInterface;
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
import com.GameInterface.Game.Shortcut;
import com.GameInterface.Game.ShortcutBase;
import com.GameInterface.Game.ShortcutData;

class com.theck.GodMode.GodMode 
{
	static var debugMode:Boolean = false;
	
	// Version
	static var version:String = "0.55";
	
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
	
	// Stat Collection
	private var last_combat_time:Number;
	
	private var time_aggregator:Object = {};
	private var bf_aggregator:Object = {};
	private var grenade_aggregator:Object = {};
	
	private var long_term_time_aggregator:Object = {};
	private var long_term_bf_aggregator:Object = {};
	private var long_term_grenade_aggregator:Object = {};
	
	private var last_used_id:Number;	
	
	
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
		Config.NewSetting("textlog", false, "");
		Config.NewSetting("stats", false, "");
		
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
		ClearAccumulators();
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
	
	private function UpdateDisplay() {
		
		SetVisible(m_Indicator, (auto_loader_counter > 0 ) );
	}
	
	
	//////////////////////////////////////////////////////////
	// Core Logic
	//////////////////////////////////////////////////////////
	
	private function IsRifleEquipped():Boolean {
		// check which slot contains that weapon
		var main_hand_item:InventoryItem = m_weaponInventory.GetItemAt(_global.Enums.ItemEquipLocation.e_Wear_First_WeaponSlot);
		var off_hand_item:InventoryItem = m_weaponInventory.GetItemAt(_global.Enums.ItemEquipLocation.e_Wear_Second_WeaponSlot);
		
		return ( main_hand_item.m_Type == 524608 || off_hand_item.m_Type == 524608 ) 
	}
	
	private function EnterCombat() {
		
		Debug("CM: entered combat");
		
		// if AL is active and we didn't already register that, fix auto_loader_counter
		if ( m_player.m_InvisibleBuffList[9257112] && auto_loader_counter == 0 ) {
			auto_loader_counter = 0.5;
		}
		Debug("alc=" + auto_loader_counter);
		
		// update the combat time 
		last_combat_time = getTimer();
		
		// initialize aggregators
		bf_aggregator[auto_loader_counter] = 0;
		grenade_aggregator[auto_loader_counter] = 0;
		time_aggregator[auto_loader_counter] = 0;
	}
		
	private function ParseCompletedCast(id:Number, type:Number) {
		
		// filter on type, 32 means the cooldown has started
		if ( last_used_id == 6806479 && id == 6806479 && type == 32 ) {
			
			// don't count this BF if grenade is already active
			if ( ! m_player.m_InvisibleBuffList[9255809] ) {
				
				if ( m_player.IsInCombat() ) {
					IncrementBFAggregator();				
				}
				else {
					setTimeout(Delegate.create(this, IncrementBFAggregator), 100);
					Debug("OCT: triggered before combat");
				}	
			}
			else {
				Debug("OCT: BF cast while grenade already active");
			}
			last_used_id = 0;
		}
	}
	
	private function OnInvisibleBuffAdded(id:Number) {
		
		// if AL procs
		if ( id == 9257112 ) {
			
			// update time aggregator setup
			time_aggregator[auto_loader_counter] = ( getTimer() - last_combat_time );
			//Debug("OIBA: t_a[" + auto_loader_counter + "]=" + time_aggregator[auto_loader_counter] );
			last_combat_time = getTimer();
			
			if ( debugMode ) {
				var bf:Number  = bf_aggregator[auto_loader_counter];
				var gn:Number  = grenade_aggregator[auto_loader_counter];
				var t:Number = time_aggregator[auto_loader_counter] / 1000;
				var pct:Number = Math.round(gn / bf * 1000) / 10;
				var gpm:Number = Math.round( gn / t * 60 * 10 ) / 10;
				Debug("OIBA: stats for alc=" + auto_loader_counter + ": G=" + gn + ", BF=" + bf + ", " + pct + "%, gpm = " + gpm );
			}
			
			// increment AL counter
			auto_loader_counter++;
			
			// initialize aggregators
			bf_aggregator[auto_loader_counter] = 0;
			grenade_aggregator[auto_loader_counter] = 0;
			time_aggregator[auto_loader_counter] = 0;
			
			// update GUI
			UpdateDisplay();
			
			// reporting for verbose mode
			if ( Config.GetValue("textlog") ) {
				com.GameInterface.UtilsBase.PrintChatText("GM: Enabled - proc " + auto_loader_counter);
			}
		}
		
		// log grenades
		else if ( id == 9255809 ) {
			if ( ! grenade_aggregator[auto_loader_counter] ) {
				grenade_aggregator[auto_loader_counter] = 1;
				//Debug("OIBA: grenade_agg undefined, set to 1")
			}
			else {
				grenade_aggregator[auto_loader_counter]++;
			}
			//Debug("OIBA: Grenades: " + grenade_aggregator[auto_loader_counter]);
		}
	}
	
	private function LeaveCombat() {
		
		Debug("CM: left combat");
		
		// update time aggregator
		time_aggregator[auto_loader_counter] = ( getTimer() - last_combat_time );
		
		// clear last_combat_time
		last_combat_time = undefined;
		
		// add to long-term variables for permanent storage
		// skip if there are no BFs at all
		if ( bf_aggregator[0] > 0 || bf_aggregator[0.5] > 0 ) {
			for ( var i in bf_aggregator ) {
				// initialize if we don't already have entries here
				if ( ! long_term_bf_aggregator[i] ) { long_term_bf_aggregator[i] = 0 };
				if ( ! long_term_grenade_aggregator[i] ) { long_term_grenade_aggregator[i] = 0 };
				if ( ! long_term_time_aggregator[i] ) { long_term_time_aggregator[i] = 0 };
				
				// add to aggregators
				long_term_bf_aggregator[i] += bf_aggregator[i];
				long_term_grenade_aggregator[i] += grenade_aggregator[i];
				long_term_time_aggregator[i] += time_aggregator[i];
			}
		}
				
		// report stats if enabled
		if ( Config.GetValue("stats", false) ) {
			ReportStats(grenade_aggregator, bf_aggregator, time_aggregator, auto_loader_counter, "Current");
			ReportOverallStats();
		}
		
		// TODO: move this to entering combat? Should be OK because we're delaying counting until after combat has registered? Or will this mess up grenades (e.g. grenade proc before combat registers)
		// if you end combat with an Auto-Loader buff, you retain the bonus for next combat
		if ( m_player.m_InvisibleBuffList[9257112] ) {
			auto_loader_counter = 0.5;
		}
		// otherwise you lose it
		else {
			auto_loader_counter = 0;
		}
		
		// update display
		UpdateDisplay();
				
		// Clear stats for next combat
		ClearAccumulators();
	}
		
	private function ClearAccumulators() {
		
		for (var i in bf_aggregator ) {
			bf_aggregator[i] = 0;
		}
		for (var i in grenade_aggregator) {
			grenade_aggregator[i] = 0;
		}
		for (var i in time_aggregator) {
			time_aggregator[i] = 0;
		}
	}
	
	private function IncrementBFAggregator() {
		
		if ( m_player.IsInCombat() ) {
				
			if ( ! bf_aggregator[auto_loader_counter] ) {
				bf_aggregator[auto_loader_counter] = 1;
			}
			else {
				bf_aggregator[auto_loader_counter]++;				
			}
		}
	}
	
	private function ResetAutoLoaderCounter() {
		auto_loader_counter = 0;
		Debug("RALC: alc=" + auto_loader_counter);
	}
	
	
	//////////////////////////////////////////////////////////
	// Reporting
	//////////////////////////////////////////////////////////
	
	
	private function ReportStats(g_agg:Object, b_agg:Object, t_agg:Object, alc:Number, text:String) {
		Print("God Mode Stats Report: " + text);
		var bf_total:Number = 0;
		var grenade_total:Number = 0;
		var time_total:Number = 0;
		
		var firstindex:Number = 0;
		if ( ! b_agg[0] && b_agg[0.5] ) { firstindex = 0.5 };
		
		Print ( " AL     BF      G       t         %      GPM");
			
		for (var i:Number = firstindex; i <= alc; i++ ) {
			var bfpct:Number = Math.round( g_agg[i] / Math.max( b_agg[i], 1) * 1000 ) / 10;
			var gpm:Number = Math.round( g_agg[i] / Math.max(t_agg[i], 1) * 60000 * 10 ) / 10;
			bf_total += b_agg[i];
			grenade_total += g_agg[i];
			time_total += t_agg[i] / 1000;
			
			Print( FormatNumberToFixedWidthString( i, 3 )  + 
					FormatNumberToFixedWidthString( b_agg[i], 8 ) + 
					FormatNumberToFixedWidthString( g_agg[i], 8 ) + 
					FormatNumberToFixedWidthString( Math.round( t_agg[i] / 100 ) / 10, 8 ) + 
					FormatNumberToFixedWidthString( Math.round( bfpct * 10 ) / 10, 8) + "%" + 
					FormatNumberToFixedWidthString( gpm, 8 )
				);			
		}
		Print("all" + FormatNumberToFixedWidthString( bf_total, 8 ) + 
					FormatNumberToFixedWidthString( grenade_total, 8) + 
					FormatNumberToFixedWidthString( Math.round( time_total * 10 ) / 10, 8 ) + 
					FormatNumberToFixedWidthString( Math.round( grenade_total / bf_total * 1000 ) / 10, 8) + "%" +
					FormatNumberToFixedWidthString( Math.round( grenade_total / time_total * 60 * 10 ) / 10, 8) 
		);
	}
	
	private function FormatNumberToFixedWidthString( num:Number, chars:Number):String {
		// pads front of number with spaces to reach desired width
		var str:String = "";
		str += num;
		//Debug("str.length = " + str.length)
		while ( str.length < chars ) {
			str = " " + str;
		}
		return str;
	}
	
	private function ReportOverallStats() {
		Print("God Mode Stats Report: Overall");
		var bf_total:Number = 0;
		var grenade_total:Number = 0;
		var time_total:Number = 0;
		
		var b_agg:Object = long_term_bf_aggregator;
		var g_agg:Object = long_term_grenade_aggregator;
		var t_agg:Object = long_term_time_aggregator;
		
		Print ( " AL     BF      G       t         %      GPM");
		
		// these can have integer and half-integer values. Loop on half-integers and see if there's any data, if not, skip
		// loop to 50, that should be sufficient
		for (var i:Number = 0; i <= 50; i = i + 0.5 ) {
			if ( ( b_agg[i] != undefined ) && ( g_agg[i] != undefined ) && ( t_agg[i] != undefined ) ) {
				var bfpct:Number = Math.round( g_agg[i] / Math.max( b_agg[i], 1) * 1000 ) / 10;
				var gpm:Number = Math.round( g_agg[i] / Math.max(t_agg[i], 1) * 60000 * 10 ) / 10;
				bf_total += b_agg[i];
				grenade_total += g_agg[i];
				time_total += t_agg[i] / 1000;
				
				Print( FormatNumberToFixedWidthString( i, 3 )  + 
						FormatNumberToFixedWidthString( b_agg[i], 8 ) + 
						FormatNumberToFixedWidthString( g_agg[i], 8 ) + 
						FormatNumberToFixedWidthString( Math.round( t_agg[i] / 100 ) / 10, 8 ) + 
						FormatNumberToFixedWidthString( Math.round( bfpct * 10 ) / 10, 8) + "%" + 
						FormatNumberToFixedWidthString( gpm, 8 )
					);			
			}
		}
		Print("all" + FormatNumberToFixedWidthString( bf_total, 8 ) + 
					FormatNumberToFixedWidthString( grenade_total, 8) + 
					FormatNumberToFixedWidthString( Math.round( time_total * 10 ) / 10, 8 ) + 
					FormatNumberToFixedWidthString( Math.round( grenade_total / bf_total * 1000 ) / 10, 8) + "%" +
					FormatNumberToFixedWidthString( Math.round( grenade_total / time_total * 60 * 10 ) / 10, 8) 
		);		
	}
	
	
	//////////////////////////////////////////////////////////
	// Signal Handling
	//////////////////////////////////////////////////////////
	
	private function OnWeaponChange() {
		if IsRifleEquipped() {
			// connect signals
			Debug("rifle connected");
			m_player.SignalToggleCombat.Connect(OnToggleCombat, this);
			m_player.SignalInvisibleBuffAdded.Connect(OnInvisibleBuffAdded, this);
			Shortcut.SignalCooldownTime.Connect(OnCooldownTime, this);
			Shortcut.SignalShortcutUsed.Connect(OnShortcutUsed, this);
			WaypointInterface.SignalPlayfieldChanged.Connect(ResetAutoLoaderCounter, this);
			
			
			// not used
			//m_player.SignalCommandStarted.Connect(OnCommandStarted, this);
			//m_player.SignalCommandEnded.Connect(OnCommandEnded, this);
			//m_player.SignalCommandAborted.Connect(OnCommandAborted, this);
			//GlobalSignal.SignalDamageNumberInfo.Connect(OnDamageNumberInfo, this);
			//GlobalSignal.SignalDamageTextInfo.Connect(OnDamageTextInfo, this);
			//Shortcut.SignalShortcutAddedToQueue.Connect(OnShortcutAddedToQueue, this);
		}
		else {
			// disconnect signals
			m_player.SignalToggleCombat.Disconnect(OnToggleCombat, this);
			m_player.SignalInvisibleBuffAdded.Disconnect(OnInvisibleBuffAdded, this);
			Shortcut.SignalCooldownTime.Disconnect(OnCooldownTime, this);
			Shortcut.SignalShortcutUsed.Disconnect(OnShortcutUsed, this);
			WaypointInterface.SignalPlayfieldChanged.Disconnect(ResetAutoLoaderCounter, this);
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
		
	private function OnCooldownTime(itemPos:Number, cooldownStart:Number, cooldownEnd:Number, cooldownType:Number ) {
		
		var spellID:Number = Shortcut.m_ShortcutList[itemPos].m_SpellId;
		
		ParseCompletedCast(spellID, cooldownType);
	}

	
	private function OnShortcutUsed(itemPos:Number) {
		
		var spellID = Shortcut.m_ShortcutList[itemPos].m_SpellId;
		
		// set last used ID
		last_used_id = spellID;
	}
	
	private function OnToggleCombat(state:Boolean) {
		
		// on leaving combat
		if ( state ) {
			EnterCombat();
		}
		else {
			LeaveCombat();
		}
		
/*		if ( ! state ) {
			Debug("CM: left combat");
			if ( Config.GetValue("textlog") ) {
				com.GameInterface.UtilsBase.PrintChatText("GM: Left Combat - proc " + auto_loader_counter);
			}
			
			// update time aggregator
			time_aggregator[auto_loader_counter] = ( getTimer() - last_combat_time );
			//Debug("CM: t_a[" + auto_loader_counter + "]=" + time_aggregator[auto_loader_counter] );
			last_combat_time = undefined;
			
			// add to long-term variables for permanent storage
			// skip if there are no BFs at all
			if ( bf_aggregator[0] > 0 || bf_aggregator[0.5] > 0 ) {
				for ( var i in bf_aggregator ) {
					// initialize if we don't already have entries here
					if ( ! long_term_bf_aggregator[i] ) { long_term_bf_aggregator[i] = 0 };
					if ( ! long_term_grenade_aggregator[i] ) { long_term_grenade_aggregator[i] = 0 };
					if ( ! long_term_time_aggregator[i] ) { long_term_time_aggregator[i] = 0 };
					
					// add to aggregators
					long_term_bf_aggregator[i] += bf_aggregator[i];
					long_term_grenade_aggregator[i] += grenade_aggregator[i];
					long_term_time_aggregator[i] += time_aggregator[i];
				}
			}
			
			
			// report stats if enabled
			if ( Config.GetValue("stats", false) ) {
				ReportStats(grenade_aggregator, bf_aggregator, time_aggregator, auto_loader_counter, "Current");
				//ReportStats(long_term_grenade_aggregator, long_term_bf_aggregator, long_term_time_aggregator, auto_loader_counter, "Overall");
				ReportOverallStats();
			}
			
			// TODO: move this to entering combat? Should be OK because we're delaying counting until after combat has registered? Or will this mess up grenades (e.g. grenade proc before combat registers)
			// if you end combat with an Auto-Loader buff, you retain the bonus for next combat
			if ( m_player.m_InvisibleBuffList[9257112] ) {
				auto_loader_counter = 0.5;
			}
			// otherwise you lose it
			else {
				auto_loader_counter = 0;
			}
			
			UpdateDisplay();
			
			
			// Clear stats for next combat
			ClearAccumulators();
		}
		
		// on entering combat
		else {
			Debug("CM: entered combat");
			if ( m_player.m_InvisibleBuffList[9257112] ) {
				Debug("CM: AL present");
			}
			else {
				Debug("CM: AL not present");
			}
			//Debug("CM: AL is present=" + m_player.m_BuffList[9257112] );
			Debug("alc=" + auto_loader_counter);
			last_combat_time = getTimer();
			bf_aggregator[auto_loader_counter] = 0;
			grenade_aggregator[auto_loader_counter] = 0;
			time_aggregator[auto_loader_counter] = 0;
			//Debug("CM: g_a=" + grenade_aggregator[auto_loader_counter]);
		}*/
	}
	
/*	// None of these are used anymore
	private function OnCommandStarted(spell:Object) {
		Debug("OCS " + spell );
	}
	private function OnCommandEnded() {
		Debug("OCE, combat=" + m_player.IsInCombat() );
	}
	private function OnCommandAborted() {
		Debug("OCA");
	}
	
	private function OnDamageNumberInfo(statID:Number,damage:Number,absorb:Number, attackResultType:Number, attackType:Number,  attackOffensiveLevel:Number, attackDefensiveLevel:Number, context:Number, targetID:ID32, iconID:ID32, iconColorLine:Number, combatLogFeedbackType:Number) {
		Debug("ODNI: context=" + context + ", iconId=" + iconID + ", clft=" + combatLogFeedbackType + ", attackType=" + attackType);
	}
	
	private function OnDamageTextInfo(text:String, context:Number, targetID:ID32) {
		Debug("ODTI: text=" + text + ", context=" + context + ", targetId=" + targetID);
	}
	
	private function OnShortcutAddedToQueue(itemPos:Number) {
		Debug("OSATQ: itemPos=" + itemPos);		
	}*/
	

	
	
	//////////////////////////////////////////////////////////
	// Debugging
	//////////////////////////////////////////////////////////
	
	private function Debug(text:String) {
		if debugMode { com.GameInterface.UtilsBase.PrintChatText("GM:" + text ); }
	}
	
	private function Print(text:String) {
		com.GameInterface.UtilsBase.PrintChatText( text );
	}
	
}