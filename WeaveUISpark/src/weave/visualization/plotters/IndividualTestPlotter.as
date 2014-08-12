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

package weave.visualization.plotters
{
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.display.Shape;
	
	import weave.Weave;
	import weave.api.data.IColumnStatistics;
	import weave.api.data.IQualifiedKey;
	import weave.api.getCallbackCollection;
	import weave.api.newDisposableChild;
	import weave.api.newLinkableChild;
	import weave.api.primitives.IBounds2D;
	import weave.api.registerLinkableChild;
	import weave.api.ui.IObjectWithSelectableAttributes;
	import weave.api.ui.IPlotTask;
	import weave.api.ui.IPlotter;
	import weave.core.LinkableNumber;
	import weave.core.LinkableWatcher;
	import weave.data.AttributeColumns.BinnedColumn;
	import weave.data.AttributeColumns.ColorColumn;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.data.AttributeColumns.FilteredColumn;
	import weave.visualization.plotters.styles.SolidFillStyle;
	import weave.visualization.plotters.styles.SolidLineStyle;
	
	public class IndividualTestPlotter extends AbstractGlyphPlotter implements IObjectWithSelectableAttributes
	{
		WeaveAPI.ClassRegistry.registerImplementation(IPlotter, IndividualTestPlotter, "IndividualTestTool");
		
		public function IndividualTestPlotter()
		{
			fill.color.internalDynamicColumn.globalName = Weave.DEFAULT_COLOR_COLUMN;
			fill.color.internalDynamicColumn.addImmediateCallback(this, handleColor, true);
			getCallbackCollection(colorDataWatcher).addImmediateCallback(this, updateKeySources, true);
		}
		
		public function getSelectableAttributeNames():Array
		{
			return ["X", "Y", "Color","Size"];
		}
		public function getSelectableAttributes():Array
		{
			return [dataX, dataY, fill.color,sizeBy];
		}
		
		public const sizeBy:DynamicColumn = newLinkableChild(this, DynamicColumn);
		public const minScreenRadius:LinkableNumber = registerLinkableChild(this, new LinkableNumber(3, isFinite));
		public const maxScreenRadius:LinkableNumber = registerLinkableChild(this, new LinkableNumber(25, isFinite));
		public const defaultScreenRadius:LinkableNumber = registerLinkableChild(this, new LinkableNumber(5, isFinite));
		
		public const line:SolidLineStyle = newLinkableChild(this, SolidLineStyle);
		public const fill:SolidFillStyle = newLinkableChild(this, SolidFillStyle);
		public const colorNegative:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0x800000));
		public const colorPositive:LinkableNumber = registerLinkableChild(this, new LinkableNumber(0x008000));
		
		// delare dependency on statistics (for norm values)
		private const _sizeByStats:IColumnStatistics = registerLinkableChild(this, WeaveAPI.StatisticsCache.getColumnStatistics(sizeBy));
		public var hack_horizontalBackgroundLineStyle:Array;
		public var hack_verticalBackgroundLineStyle:Array;
		
		private const colorDataWatcher:LinkableWatcher = newDisposableChild(this, LinkableWatcher);
		
		private var _extraKeyDependencies:Array;
		private var _keyInclusionLogic:Function;
		
		public function hack_setKeyInclusionLogic(keyInclusionLogic:Function, extraColumnDependencies:Array):void
		{
			_extraKeyDependencies = extraColumnDependencies;
			_keyInclusionLogic = keyInclusionLogic;
			updateKeySources();
		}
		
		private function handleColor():void
		{
			var cc:ColorColumn = fill.color.getInternalColumn() as ColorColumn;
			var bc:BinnedColumn = cc ? cc.getInternalColumn() as BinnedColumn : null;
			var fc:FilteredColumn = bc ? bc.getInternalColumn() as FilteredColumn : null;
			var dc:DynamicColumn = fc ? fc.internalDynamicColumn : null;
			colorDataWatcher.target = dc || fc || bc || cc;
		}
		
		private function updateKeySources():void
		{
			var columns:Array = [sizeBy];
			if (colorDataWatcher.target)
				columns.push(colorDataWatcher.target)
			columns.push(dataX, dataY);
			if (_extraKeyDependencies)
				columns = columns.concat(_extraKeyDependencies);
			
			_filteredKeySet.setColumnKeySources(columns, [true], null, _keyInclusionLogic);
		}
		
		override public function drawBackground(dataBounds:IBounds2D, screenBounds:IBounds2D, destination:BitmapData):void
		{
			if (!filteredKeySet.keys.length)
				return;
			if (hack_horizontalBackgroundLineStyle)
			{
				tempShape.graphics.clear();
				tempShape.graphics.lineStyle.apply(null, hack_horizontalBackgroundLineStyle);
				tempShape.graphics.moveTo(screenBounds.getXMin(), screenBounds.getYCenter());
				tempShape.graphics.lineTo(screenBounds.getXMax(), screenBounds.getYCenter());
				destination.draw(tempShape);
			}
			if (hack_verticalBackgroundLineStyle)
			{
				tempShape.graphics.clear();
				tempShape.graphics.lineStyle.apply(null, hack_verticalBackgroundLineStyle);
				tempShape.graphics.moveTo(screenBounds.getXCenter(), screenBounds.getYMin());
				tempShape.graphics.lineTo(screenBounds.getXCenter(), screenBounds.getYMax());
				destination.draw(tempShape);
			}
		}
		
		override public function drawPlotAsyncIteration(task:IPlotTask):Number
		{
			// this template will draw one record per iteration
			if (task.iteration == 0)
			{
				if (!task.asyncState)
					task.asyncState = {};
			}
			return super.drawPlotAsyncIteration(task);
		}
		
		/**
		 * This function may be defined by a class that extends AbstractPlotter to use the basic template code in AbstractPlotter.drawPlot().
		 */
		override protected function addRecordGraphicsToTempShape(recordKey:IQualifiedKey, dataBounds:IBounds2D, screenBounds:IBounds2D, tempShape:Shape):void
		{
			var graphics:Graphics = tempShape.graphics;
			graphics.clear();
			
			// project data coordinates to screen coordinates and draw graphics
			getCoordsFromRecordKey(recordKey, tempPoint);
			
			dataBounds.projectPointTo(tempPoint, screenBounds);
			
			line.beginLineStyle(recordKey, graphics);
			fill.beginFillStyle(recordKey, graphics);
			
			var radius:Number;
			if (sizeBy.internalObject)
			{
				radius = minScreenRadius.value + (_sizeByStats.getNorm(recordKey) * (maxScreenRadius.value - minScreenRadius.value));
			}
			else
				radius = defaultScreenRadius.value;
			if (!isFinite(radius))
			{
				// handle undefined radius
				// draw default circle
				graphics.drawRect(tempPoint.x, tempPoint.y, defaultScreenRadius.value, defaultScreenRadius.value );
			}
			else
			{
				//trace('circle',tempPoint);
				graphics.drawRect(tempPoint.x, tempPoint.y, radius, radius);
			}
			graphics.endFill();
		}
	}
}
