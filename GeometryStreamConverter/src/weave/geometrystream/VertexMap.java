/* ***** BEGIN LICENSE BLOCK *****
 *
 * This file is part of Weave.
 *
 * The Initial Developer of Weave is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2015
 * the Initial Developer. All Rights Reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 * ***** END LICENSE BLOCK ***** */

package weave.geometrystream;

import java.util.HashMap;
import java.util.LinkedList;

/**
 * @author adufilie
 */
public class VertexMap
{
	/**
	 * This Map is used as a hash lookup for CombinedPoint objects.
	 * Using this Map, we can look up a CombinedPoint object and add new vertex IDs to it.
	 */
	private final HashMap<CombinedPoint, CombinedPoint> map = new HashMap<CombinedPoint, CombinedPoint>();
	
	private final LinkedList<PartMarker> partMarkers = new LinkedList<PartMarker>();

	public int getCombinedPointCount()
	{
		return map.size();
	}
	
	private int totalStreamSize = 0;
	public int getTotalStreamSize()
	{
		return totalStreamSize;
	}
	
	public void addPartMarker(int shapeID, int firstVertexID, int chainLength, Bounds2D partBounds)
	{
		PartMarker pm = new PartMarker(shapeID, firstVertexID, chainLength, partBounds);
		partMarkers.add(pm);
		totalStreamSize += pm.getStreamSize();
	}
	
	private final CombinedPoint searchPoint = new CombinedPoint(Double.NaN, Double.NaN);
	
	/**
	 * This will call CombinedPoint.addPoint() on a CombinedPoint object matching
	 * the x,y coordinates of the given vertex.
	 * @param shapeID The ID of the shape in which the vertex exists.
	 * @param point Information about a vertex in the specified shape.
	 * @param maxImportance Maximum possible importance to use in place of VertexChainLink.IMPORTANCE_REQUIRED
	 */
	public void addPoint(int shapeID, VertexChainLink point, double maxImportance, Bounds2D partBounds)
	{
		// get a new CombinedPoint object to be used when a
		searchPoint.x = point.x;
		searchPoint.y = point.y;

		// check the hash map for a matching CombinedPoint object
		CombinedPoint existingCombinedPoint = map.get(searchPoint);
		if (existingCombinedPoint == null)
		{
			CombinedPoint newCombinedPoint = new CombinedPoint(point.x, point.y);
			// hash map doesn't have a matching CombinedPoint object, so save the new one
			map.put(newCombinedPoint, newCombinedPoint);
			totalStreamSize += newCombinedPoint.getStreamSize(); // include new CombinedPoint in total stream size
			existingCombinedPoint = newCombinedPoint;
		}

		// add a VertexIdentifier to the existing CombinedPoint and update total stream size
		totalStreamSize -= existingCombinedPoint.getStreamSize();
		existingCombinedPoint.addPoint(shapeID, point, partBounds);
		totalStreamSize += existingCombinedPoint.getStreamSize();
		
		// update importance
		double importance = point.importance;
		if (importance == VertexChainLink.IMPORTANCE_REQUIRED)
			importance = maxImportance;
		existingCombinedPoint.updateMinimumImportance(importance);
	}

	/**
	 * This function retrieves all the CombinedPoint objects that have been generated by calls to addPoint().
	 * @return A Vector of CombinedPoint objects.
	 */
	public LinkedList<IStreamObject> getStreamObjects()
	{
		LinkedList<IStreamObject> result = new LinkedList<IStreamObject>(map.values());
		result.addAll(partMarkers);
		return result;
	}

	/**
	 * This returns all CombinedPoint instances this object is using back to the CombinedPoint object pool.
	 */
	public void clear()
	{
		map.clear();
		partMarkers.clear();
		totalStreamSize = 0;
	}
}
