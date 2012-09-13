/*
    Weave (Web-based Analysis and Visualization Environment)
    Copyright (C) 2008-2011 University of Massachusetts Lowell

    This file is a part of Weave.

    Weave is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License, Version 3,
    as published by the Free Software Foundation.

    Weave is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/

package weave.ui
{
	import flash.events.Event;
	import flash.utils.getTimer;
	
	import mx.core.UIComponent;
	
	import weave.api.WeaveAPI;
	import weave.api.core.ILinkableObject;
	import weave.compiler.StandardLib;

	/**
	 * This is a component that shows a busy animation.
	 * It will animate automatically when added to the stage.
	 * It will not animate when the <code>visible</code> property is set to false.
	 * 
	 * @author adufilie
	 */
	public class BusyIndicator extends UIComponent
	{
		public function BusyIndicator(target:ILinkableObject = null, ...moreTargets)
		{
			super();
			moreTargets.unshift(target);
			this.targets = moreTargets;
			includeInLayout = false;
			mouseChildren = false;
			addEventListener(Event.FRAME_CONSTRUCTED, render);
		}
		
		/**
		 * This is an Array of ILinkableObjects whose busy status should be monitored.
		 */		
		public var targets:Array; /* of ILinkableObject */
		
		public var fps:Number = 12;//24;
		public var bgColor:uint = 0x000000
		public var bgAlpha:Number = 0x000000
		public var colorSwitchTime:Number = 1; // number of revolutions between color switch
		public var colorStartList:Array = [0xa0a0a0, 0x404040, 0xa0a0a0];
		public var colorEndList:Array = [0xa0a0a0, 0x404040, 0xa0a0a0];
		public var alphaStart:Number = 1;
		public var alphaEnd:Number = 0;
		public var diameterRatio:Number = 0.25;
		public var circleRatio:Number = 0.2;
		public var numCircles:uint = 12;
		private var prevFrame:int = -1;
		private var timeBecameBusy:int = 0;
		public var autoVisibleDelay:int = 500;
		
		/**
		 * This will update the graphics immediately when set.
		 */
		override public function set visible(value:Boolean):void
		{
			super.visible = value;
			render();
		}
		
		/**
		 * This will automatically toggle visibility based the target's busy status.
		 */
		private function toggleVisible():void
		{
			var busy:Boolean = false;
			for each (var target:ILinkableObject in targets)
			{
				if (WeaveAPI.SessionManager.linkableObjectIsBusy(target))
				{
					busy = true;
					break;
				}
			}
			if (visible != busy)
			{
				if (busy)
				{
					if (timeBecameBusy == -1)
						timeBecameBusy = getTimer();
					if (getTimer() - timeBecameBusy < autoVisibleDelay)
						return;
				}
				
				visible = busy;
			}
			timeBecameBusy = -1;
		}
		
		/**
		 * This will update the graphics.
		 */
		private function render(e:Event=null):void
		{
			if (!stage)
				return;
			
			if (targets)
				toggleVisible();
			
			if (!visible)
				return;
			
			var frame:Number = (fps * getTimer() / 1000);
			
			if (prevFrame == int(frame))
				return;
			
			prevFrame = int(frame);
			
			var cx:Number = parent.width / 2 - this.x;
			var cy:Number = parent.height / 2 - this.y;
			var radius:Number = Math.min(parent.width, parent.height) * diameterRatio / 2;
			var revolution:Number = frame / numCircles;
			var colorIndexNorm:Number = revolution % (colorStartList.length - 1) / (colorStartList.length - 1);
			var colorStart:Number = StandardLib.interpolateColor(colorIndexNorm, colorStartList);
			var colorEnd:Number = StandardLib.interpolateColor(colorIndexNorm, colorEndList);
			var step:int = frame % numCircles;
			var angle:Number = Math.PI * 2 * step / numCircles;
			
			graphics.clear();
			for (var i:int = 0; i < numCircles; i++)
			{
				var norm:Number = 1 - i / (numCircles - 1);
				var color:Number = StandardLib.interpolateColor(norm, colorStart, colorEnd);
				var alpha:Number = StandardLib.scale(norm, 0, 1, alphaStart, alphaEnd)
				graphics.beginFill(color, alpha);
				graphics.drawCircle(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius, radius * circleRatio);
				graphics.endFill();
				angle += Math.PI * 2 / numCircles;
			}
		}
	}
}
