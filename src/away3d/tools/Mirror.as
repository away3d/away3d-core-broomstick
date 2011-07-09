﻿package away3d.tools
{
	import away3d.arcane;
	import away3d.containers.ObjectContainer3D;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.entities.Mesh;
	import away3d.materials.MaterialBase;
	import away3d.tools.utils.Bounds;

	import flash.geom.Vector3D;

	use namespace arcane;
	
	/**
	* Class Mirror an Object3D geometry and its uv's.<code>Mirror</code>
	*/
	public class Mirror{
		
		private static var _axes:Array = ["x-", "x+", "x", "y-", "y+", "y", "z-", "z+", "z"];
		private static const LIMIT:uint = 64998;
		
		/*
		* Mirrors one Mesh object geometry and uv's. Will apply to all meshes found if a ObjectContainer that contains more meshes is passed.
		* 
		* @param	 obj		The ObjectContainer3D are parsed recurvely as well.
		* @param	 axe		A string "x-", "x+", "x", "y-", "y+", "y", "z-", "z+", "z". "x", "y","z" mirrors on world position 0,0,0, the + mirrors geometry in positive direction, the - mirrors geometry in positive direction.
		* @param	 recenter	[optional]	Recenter the geometry. This doesn't affect ObjectContainers3D's. Default is true.
		* @param	 duplicate	[optional]	Duplicate model geometry along the axe or set to false mirror but do not duplicate. Default is true.
		*/
		public static function apply(obj:ObjectContainer3D, axe:String, recenter:Boolean = true, duplicate:Boolean = true):void
		{
			axe = axe.toLowerCase();
			 
			if(Mirror.validate(axe)){
				
				var child:ObjectContainer3D;
				
				if(obj is Mesh && ObjectContainer3D(obj).numChildren == 0)
					Mirror.build( Mesh(obj), axe, recenter, duplicate);
					 
				for(var i:uint = 0;i<ObjectContainer3D(obj).numChildren;++i){
					child = ObjectContainer3D(obj).getChildAt(i);
					Mirror.apply(child, axe, recenter, duplicate);
				}
				 
			} else {
				throw new Error("Invalid mirror axe parameter: "+Mirror._axes.toString());
			}
		}
		 
		private static function validate( axe:String):Boolean
		{
			for(var i:int =0;i<Mirror._axes.length;++i)
				if(axe == Mirror._axes[i]) return true;
				
			return false;
		}
		 

		private static function build(mesh:Mesh, axe:String, recenter:Boolean, duplicate:Boolean = true):void
		{
			var minX:Number = mesh.minX;
			var minY:Number;
			var minZ:Number;
			var maxX:Number;
			var maxY:Number;
			var maxZ:Number;
			//in case we deal with object where bounds would not be available
			if(isNaN(minX)){
				Bounds.getMeshBounds(mesh);
				minX = Bounds.minX;
				minY = Bounds.minY;
				minZ = Bounds.minZ;
				maxX = Bounds.maxX;
				maxY = Bounds.maxY;
				maxZ = Bounds.maxZ;
			} else {
				minY = mesh.minY;
				minZ = mesh.minZ;
				maxX = mesh.maxX;
				maxY = mesh.maxY;
				maxZ = mesh.maxZ;
			}
			
			var offset:Number;
			var posi:Vector3D = mesh.position;
			var mat:MaterialBase;
			
			switch(axe){
				
					case "x":
						offset = posi.x;
						break;
					case "x-":
						offset = Math.abs(minX)+maxX;
						break;
					case "x+":
						offset = Math.abs(minX)+maxX;
						break;
					
					case "y":
						offset = posi.y;
						break;
					case "y-":
						offset = Math.abs(minY)+maxY;
						break;
					case "y+":
						offset = Math.abs(minY)+maxY;
					break;
					
					case "z":
						offset = posi.z;
					break;
					case "z-":
						offset = Math.abs(minZ)+maxZ;
					break;
					case "z+":
						offset = Math.abs(minZ)+maxZ;
						
			}
			 
				var geometry:Geometry = mesh.geometry;
				var geometries:Vector.<SubGeometry> = geometry.subGeometries;
				var numSubGeoms:uint = geometries.length;
				
				var hasMultipleMaterial:Boolean;
				if(duplicate){
					var materials:Array = [];
					for (i = 0; i<mesh.subMeshes.length; ++i){
						materials.push(mesh.subMeshes[i].material);
						if(!hasMultipleMaterial && mesh.subMeshes[i].material != null)
							hasMultipleMaterial = true;
					}
					
					var matCount:uint = materials.length;
				}
				
				var sourceverts:Vector.<Number>;
				var sourceindices:Vector.<uint>;
				var sourceuvs:Vector.<Number>;
				var sourcenormals:Vector.<Number>;
				var sourcetangents:Vector.<Number>;
				
				var x:Number;
				var y:Number;
				var z:Number;
				var u:Number;
				var v:Number;
				var nx:Number;
				var ny:Number;
				var nz:Number;
				var tx:Number;
				var ty:Number;
				var tz:Number;
				
				var i:uint;
				var j:uint;
				var vectors:Array = [];
				
				for (i = 0; i<numSubGeoms; ++i){					 
					sourceverts = new Vector.<Number>();
					sourceindices = new Vector.<uint>();
					sourceuvs = new Vector.<Number>();
					sourcenormals = new Vector.<Number>();
					sourcetangents = new Vector.<Number>();
					sourceverts = SubGeometry(geometries[i]).vertexData;
					sourceindices = SubGeometry(geometries[i]).indexData;
					sourceuvs = SubGeometry(geometries[i]).UVData;
					sourcenormals = SubGeometry(geometries[i]).vertexNormalData;
					sourcetangents = SubGeometry(geometries[i]).vertexTangentData;
					
					vectors.push(sourceverts,sourceindices,sourceuvs,sourcenormals,sourcetangents);
				}
				 
				var sub_geom:SubGeometry;
				 
				var destverts:Vector.<Number>;
				var destindices:Vector.<uint>;
				var destuvs:Vector.<Number>;
				var destnormals:Vector.<Number>;
				var desttangents:Vector.<Number>;
				
				destverts = vectors[vectors.length - 5];
				destindices = vectors[vectors.length - 4];
				destuvs = vectors[vectors.length - 3];
				destnormals = vectors[vectors.length - 2];
				desttangents = vectors[vectors.length - 1];
				 
				 
				var sourceIndV:uint;
				var sourceIndU:uint;
				var sourceVertLength:uint;
				var sourceNind:uint;
				
				var destIndV:uint = destverts.length;
				var destIndI:uint = destindices.length;
				var destIndU:uint = destuvs.length;
				var destNind:uint = destIndV;
				 
				var lockIndex:uint = destIndV;
				var indiceVectors:uint;
				var isFace:int = 0;
				var addSubgeom:Boolean;
				
				//todo : check first if material is sharing a subgeometry that is not full first

				for (i = 0; i<numSubGeoms; ++i){
					 
					indiceVectors = i*5;
					sourceverts = vectors[indiceVectors];
					sourceindices = vectors[indiceVectors+1];
					sourceuvs = vectors[indiceVectors+2];
					sourcenormals = vectors[indiceVectors+3];
					sourcetangents = vectors[indiceVectors+4];
					sourceVertLength = (i == numSubGeoms-1)? lockIndex : sourceverts.length;
					sourceIndV = sourceIndU = sourceNind = 0;
					
					if(duplicate && hasMultipleMaterial)
						addSubgeom = true;
						  
					for (j = 0; j<sourceVertLength; j+=3){
						 
						if(duplicate){
							
							if(addSubgeom){
								addSubgeom = false;
								isFace = 0;
								destIndV = 0;
								destIndI = 0;
								destIndU = 0;
								destNind = 0;
								destverts = new Vector.<Number>();
								destindices = new Vector.<uint>();
								destuvs = new Vector.<Number>();
								destnormals = new Vector.<Number>();
								desttangents = new Vector.<Number>();
								vectors.push(destverts,destindices,destuvs,destnormals,desttangents);
								sub_geom = new SubGeometry();
								geometry.addSubGeometry(sub_geom);
								materials.push(materials[i]);
							}
						  
							switch(axe){
								 
								case "x":
									destverts[destIndV]  = -sourceverts[j] - (offset*2);
									if(recenter){
										if(destverts[destIndV] > maxX)
											maxX = destverts[destIndV];
										if(destverts[destIndV] < minX)
											minX = destverts[destIndV];
									}
									destIndV++;
									destverts[destIndV++]  = sourceverts[j+1];
									destverts[destIndV++]  = sourceverts[j+2];
									break;
								case "x-":
									destverts[destIndV]  = -sourceverts[j] - offset;
									if(recenter && destverts[destIndV] < minX)
										minX = destverts[destIndV];
									destIndV++;
									destverts[destIndV++]  = sourceverts[j+1];
									destverts[destIndV++]  = sourceverts[j+2];
									break;
								case "x+":
									destverts[destIndV]  = -sourceverts[j] + offset;
									if(recenter && destverts[destIndV] > maxX)
										maxX = destverts[destIndV];
									destIndV++;
									destverts[destIndV++] = sourceverts[j+1];
									destverts[destIndV++] = sourceverts[j+2];
									break;
								
								case "y":
									destverts[destIndV++]  = sourceverts[j];
									destverts[destIndV]  = -sourceverts[j+1] - (offset*2);
									if(recenter){
										if(destverts[destIndV] > maxY)
											maxY = destverts[destIndV];
										if(destverts[destIndV] < minY)
											minY = destverts[destIndV];
									}
									destIndV++;
									destverts[destIndV++]  = sourceverts[j+2];
									break;
								case "y-":
									destverts[destIndV++] = sourceverts[j];
									destverts[destIndV]  = -sourceverts[j+1] - offset;
									if(recenter && destverts[destIndV] < minY)
										minY = destverts[destIndV];
									destIndV++;
									
									destverts[destIndV++]  = sourceverts[j+2];
									break;
								case "y+":
									destverts[destIndV++] = sourceverts[j];
									destverts[destIndV]  = -sourceverts[j+1] + offset;
									if(recenter && destverts[destIndV] > maxY)
										maxY = destverts[destIndV];
									destIndV++;
									destverts[destIndV++] = sourceverts[j+2];
									break;
								
								case "z":
									destverts[destIndV++]  = sourceverts[j];
									destverts[destIndV++]  = sourceverts[j+1];
									destverts[destIndV]  = -sourceverts[j+2] - (offset*2);
									if(recenter){
										if(destverts[destIndV] > maxZ)
											maxZ = destverts[destIndV];
										if(destverts[destIndV] < minZ)
											minZ = destverts[destIndV];
									}
									destIndV++;
									break;
								case "z-":
									destverts[destIndV++]  = sourceverts[j];
									destverts[destIndV++]  = sourceverts[j+1];
									destverts[destIndV]  = -sourceverts[j+2] - offset;
									if(recenter && destverts[destIndV] < minZ)
										minZ = destverts[destIndV];
									destIndV++;
									break;
								case "z+":
									destverts[destIndV++]  = sourceverts[j];
									destverts[destIndV++]  = sourceverts[j+1];
									destverts[destIndV]  = -sourceverts[j+2] + offset;
									if(recenter && destverts[destIndV] > maxZ)
										maxZ = destverts[destIndV];
									destIndV++;
							}
							 
							destindices[destIndI] = destindices.length;
							destIndI++;
							 
							destuvs[destIndU++] = sourceuvs[sourceIndU++];
							destuvs[destIndU++] = sourceuvs[sourceIndU++];
							
							destnormals[destNind] = sourcenormals[sourceNind];
							desttangents[destNind] = sourcetangents[sourceNind];
							destNind++;
							sourceNind++;
							destnormals[destNind] = sourcenormals[sourceNind];
							desttangents[destNind] = sourcetangents[sourceNind];
							destNind++;
							sourceNind++;
							
							isFace++;
							if(isFace == 3){
								isFace = 0;
								x = destverts[destIndV-3];
								y = destverts[destIndV-2];
								z = destverts[destIndV-1];
								
								nx = destnormals[destNind-3];
								ny = destnormals[destNind-2];
								nz = destnormals[destNind-1];
								 
								tx = desttangents[destNind-3];
								ty = desttangents[destNind-2];
								tz = desttangents[destNind-1];
								
								destverts[destIndV-3] = destverts[destIndV-6];
								destverts[destIndV-2] = destverts[destIndV-5];
								destverts[destIndV-1] = destverts[destIndV-4];
								
								destnormals[destNind-3] = destnormals[destNind-6];
								destnormals[destNind-2] = destnormals[destNind-5];
								destnormals[destNind-1] = destnormals[destNind-4];
								
								desttangents[destNind-3] = desttangents[destNind-6];
								desttangents[destNind-2] = desttangents[destNind-5];
								desttangents[destNind-1] = desttangents[destNind-4];
								
								destverts[destIndV-6] = x;
								destverts[destIndV-5] = y;
								destverts[destIndV-4] = z;
								
								destnormals[destNind-6] = nx;
								destnormals[destNind-5] = ny;
								destnormals[destNind-4] = nz;
								
								desttangents[destNind-6] = tx;
								desttangents[destNind-5] = ty;
								desttangents[destNind-4] = tz;
								
								u = destuvs[destIndU-2];
								v = destuvs[destIndU-1];
								
								destuvs[destIndU-2] = destuvs[destIndU-4];
								destuvs[destIndU-1] = destuvs[destIndU-3];
								
								destuvs[destIndU-4] = u;
								destuvs[destIndU-3] = v;
								
								if(destverts.length+3 > LIMIT && (j!= sourceVertLength-1 && i!=numSubGeoms-1)){
									destIndV = 0;
									destIndI = 0;
									destIndU = 0;
									destNind = 0;
									destverts = new Vector.<Number>();
									destindices = new Vector.<uint>();
									destuvs = new Vector.<Number>();
									destnormals = new Vector.<Number>();
									desttangents = new Vector.<Number>();
									vectors.push(destverts,destindices,destuvs,destnormals,desttangents);
									sub_geom = new SubGeometry();
									geometry.addSubGeometry(sub_geom);
									
									if(duplicate )
										materials.push(materials[i]);
								}
								  
							}
							 
						} else {
							
							switch(axe){
								
								case "x":
									sourceverts[j] = -sourceverts[j] -(offset*2);
									break;
								case "x-":
									sourceverts[j] = -sourceverts[j] - offset;
									break;
								case "x+":
									sourceverts[j] = -sourceverts[j] + offset;
									break;
								
								case "y":
									sourceverts[j+1] = -sourceverts[j+1] -(offset*2);
									break;
								case "y-":
									sourceverts[j+1] = -sourceverts[j+1] - offset;
									break;
								
								case "y+":
									sourceverts[j+1] = -sourceverts[j+1] + offset;
									break;
								 
								case "z":
									sourceverts[j+2] = -sourceverts[j+2] -(offset*2);
									break;
								
								case "z-":
									sourceverts[j+2] = -sourceverts[j+2] - offset;
									break;
								
								case "z+":
									sourceverts[j+2] = -sourceverts[j+2] + offset;
							}
							
							isFace++;
							if(isFace == 3){
								isFace = 0;
								x = sourceverts[j-3];
								y = sourceverts[j-2];
								z = sourceverts[j-1];
								
								nx = sourcenormals[j-3];
								ny = sourcenormals[j-2];
								nz = sourcenormals[j-1];
								 
								tx = sourcetangents[j-3];
								ty = sourcetangents[j-2];
								tz = sourcetangents[j-1];
								
								sourceverts[j-3] = sourceverts[j-6];
								sourceverts[j-2] = sourceverts[j-5];
								sourceverts[j-1] = sourceverts[j-4];
								
								sourcenormals[j-3] = sourcenormals[j-6];
								sourcenormals[j-2] = sourcenormals[j-5];
								sourcenormals[j-1] = sourcenormals[j-4];
								
								sourcetangents[j-3] = sourcetangents[j-6];
								sourcetangents[j-2] = sourcetangents[j-5];
								sourcetangents[j-1] = sourcetangents[j-4];
								
								sourceverts[j-6] = x;
								sourceverts[j-5] = y;
								sourceverts[j-4] = z;
								
								sourcenormals[j-6] = nx;
								sourcenormals[j-5] = ny;
								sourcenormals[j-4] = nz;
								
								sourcetangents[j-6] = tx;
								sourcetangents[j-5] = ty;
								sourcetangents[j-4] = tz;
								
								destIndU = (j/3)*2;
								
								u = sourceuvs[destIndU-2];
								v = sourceuvs[destIndU-1];
								
								sourceuvs[destIndU-2] = sourceuvs[destIndU-4];
								sourceuvs[destIndU-1] = sourceuvs[destIndU-3];
								
								sourceuvs[destIndU-4] = u;
								sourceuvs[destIndU-3] = v;
							}
							
						} 
						
					}
					 
				}
			
			geometries = geometry.subGeometries;
			numSubGeoms = geometries.length;

			for (i = 0; i<numSubGeoms; ++i){
				indiceVectors = i*5;
				
				sub_geom = SubGeometry(geometry.subGeometries[i]);
				sub_geom.updateVertexData(vectors[indiceVectors]);
				sub_geom.updateIndexData(vectors[indiceVectors+1]);
				sub_geom.updateUVData(vectors[indiceVectors+2]);
				sub_geom.updateVertexNormalData(vectors[indiceVectors+3]);
				sub_geom.updateVertexTangentData(vectors[indiceVectors+4]);
			}
			 
			if(duplicate){
				var matind:uint = 0;
				for (i = matCount; i<mesh.subMeshes.length; ++i){
					if(MaterialBase(materials[matind]) != null)
						mesh.subMeshes[i].material = materials[matind];
					matind++;
				}
				
			} else if(recenter){
				//todo: do this during the non duplicate switch
				Bounds.getMeshBounds(mesh);
				minX = Bounds.minX; 
				minY = Bounds.minY; 
				minZ = Bounds.minZ; 
				maxX = Bounds.maxX; 
				maxY = Bounds.maxY; 
				maxZ = Bounds.maxZ; 
			}
			
			if(recenter)
				MeshHelper.applyPosition(mesh, (minX+maxX)*.5, (minY+maxY)*.5, (minZ+maxZ)*.5);
		}
		
	}
}