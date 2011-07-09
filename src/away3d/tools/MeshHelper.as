﻿package away3d.tools
{
	import away3d.arcane;
	import away3d.containers.ObjectContainer3D;
	import away3d.core.base.Geometry;
	import away3d.core.base.Object3D;
	import away3d.core.base.SubGeometry;
	import away3d.core.base.data.Vertex;
	import away3d.entities.Mesh;
	import away3d.loaders.parsers.data.DefaultBitmapData;
	import away3d.materials.BitmapMaterial;
	import away3d.materials.MaterialBase;
	import away3d.tools.utils.Bounds;

	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;

	use namespace arcane;
	
	/**
	* Helper Class for the Mesh object <code>MeshHelper</code>
	* A series of methods usually usefull for mesh manipulations
	*/
	 
	public class MeshHelper {
		
		private static const LIMIT:uint = 64998;
		/**
		* Returns the boundingRadius of an Entity of a Mesh.
		* @param mesh		Mesh. The mesh to get the boundingRadius from.
		*/
		public static function boundingRadius(mesh:Mesh):Number
		{
			var radius:Number;
			try{
				radius = Math.max((mesh.maxX-mesh.minX)*Object3D(mesh).scaleX, (mesh.maxY-mesh.minY)*Object3D(mesh).scaleY, (mesh.maxZ-mesh.minZ)*Object3D(mesh).scaleZ);
			}catch(e:Error){
			 	Bounds.getMeshBounds(mesh);
				radius = Math.max((Bounds.maxX-Bounds.minX)*Object3D(mesh).scaleX, (Bounds.maxY-Bounds.minY)*Object3D(mesh).scaleY, (Bounds.maxZ-Bounds.minZ)*Object3D(mesh).scaleZ);
			}
			
			return radius *.5;
		}
		
		/**
		* Returns the boundingRadius of a ObjectContainer3D
		* @param container		ObjectContainer3D. The ObjectContainer3D and its children to get the boundingRadius from.
		*/
		public static function boundingRadiusContainer(container:ObjectContainer3D):Number
		{
			Bounds.getObjectContainerBounds(container);
			var radius:Number = Math.max((Bounds.maxX-Bounds.minX)*Object3D(container).scaleX, (Bounds.maxY-Bounds.minY)*Object3D(container).scaleY, (Bounds.maxZ-Bounds.minZ)*Object3D(container).scaleZ);
			return radius *.5;
		}
		 
		/**
		* Recenter geometry, (its pivot is at center of geometry)
		* @param mesh				Mesh. The Mesh to offset
		*/
		public static function recenter(mesh:Mesh):void
		{
			// to do prevent mesh clears bounds if more subgeometries are updated. bounds reset per subgeoms instead of total subgeoms
			/*try{
				applyPosition(mesh, (mesh.minX+mesh.maxX)*.5, (mesh.minY+mesh.maxY)*.5, (mesh.minZ+mesh.maxZ)*.5);
			}catch(e:Error){*/
				Bounds.getMeshBounds(mesh);
				applyPosition(mesh, (Bounds.minX+Bounds.maxX)*.5, (Bounds.minY+Bounds.maxY)*.5, (Bounds.minZ+Bounds.maxZ)*.5);
			//}
			
		}
		
		/**
		* Applys the rotation values of a mesh in object space and resets rotations to zero.
		* @param mesh				Mesh. The Mesh to alter
		*/
		public static function applyRotations(mesh:Mesh):void
		{
			var geometry:Geometry = mesh.geometry;
			var geometries:Vector.<SubGeometry> = geometry.subGeometries;
			var numSubGeoms:int = geometries.length;
			var vertices:Vector.<Number>;
			var verticesLength: uint;
			var j: uint;
			var t:Matrix3D = mesh.transform;
			var holder:Vector3D = new Vector3D();
			var yind:uint;
			var zind:uint;
			var subGeom:SubGeometry;
			
			for (var i :uint = 0; i<numSubGeoms; ++i){
					subGeom = SubGeometry(geometries[i]);
					vertices = subGeom.vertexData;
					verticesLength = vertices.length;
					 
					for (j = 0; j<verticesLength; j+=3){
						holder.x = vertices[j];
						holder.y = vertices[yind = j+1];
						holder.z = vertices[zind = j+2];
						holder = t.deltaTransformVector(holder);
						vertices[j] = holder.x;
						vertices[yind] = holder.y;
						vertices[zind] = holder.z;
					}
					
					subGeom.updateVertexData(vertices);
			}
			mesh.rotationX = mesh.rotationY = mesh.rotationZ = 0; 
		}
		
		/**
		* Applys an offset to a mesh at vertices level
		* @param mesh				Mesh. The Mesh to offset
		* @param dx					Number. The offset along the x axis
		* @param dy					Number. The offset along the y axis
		* @param dz					Number. The offset along the z axis
		*/
		public static function applyPosition(mesh:Mesh, dx:Number, dy:Number, dz:Number):void
		{
			var geometry:Geometry = mesh.geometry;
			var geometries:Vector.<SubGeometry> = geometry.subGeometries;
			var numSubGeoms:int = geometries.length;
			var vertices:Vector.<Number>;
			var verticesLength: uint;
			var j: uint;
			var subGeom:SubGeometry;
			for (var i :uint = 0; i<numSubGeoms; ++i){
					subGeom = SubGeometry(geometries[i]);
					vertices = subGeom.vertexData;
					verticesLength = vertices.length;
					 
					for (j = 0; j<verticesLength; j+=3){
						vertices[j] -= dx;
						vertices[j+1] -= dy;
						vertices[j+2] -= dz;
					}
					
					subGeom.updateVertexData(vertices);
			}
		}
		
		/**
		* Duplicates a Mesh
		* @param mesh				Mesh. The mesh to duplicate
		* @param newname		[optional] String. new name for the duplicated mesh. Default = "";
		*/
		public static function duplicate(mesh:Mesh, newName:String = ""):Mesh
		{
			var geometry:Geometry = mesh.geometry.clone();
			var newMesh:Mesh = new Mesh(mesh.material, geometry);
			newMesh.name = newName;
			
			return newMesh;
		}
		
		/**
		* Inverts the faces of all the Meshes into an ObjectContainer3D
		* @param obj		ObjectContainer3D. The ObjectContainer3D to invert.
		*/
		public static function invertContainerFaces(obj:ObjectContainer3D):void
		{
			var child:ObjectContainer3D;
				
				if(obj is Mesh && ObjectContainer3D(obj).numChildren == 0)
					invertFaces(Mesh(obj));
					 
				for(var i:uint = 0;i<ObjectContainer3D(obj).numChildren;++i){
					child = ObjectContainer3D(obj).getChildAt(i);
					invertContainerFaces(child);
				}
			
		}
		
		/**
		* Inverts the faces of a Mesh
		* @param mesh		Mesh. The Mesh to invert.
		*/
		public static function invertFaces(mesh:Mesh):void
		{
			var subGeometries:Vector.<SubGeometry> = mesh.geometry.subGeometries;
			var numSubGeoms:uint = subGeometries.length;
			var indices:Vector.<uint>;
			var normals:Vector.<Number>;
			var tangents:Vector.<Number>;
			var i:uint;
			var j:uint;
			var ind:uint;
			var indV0:uint;
			var subGeom:SubGeometry;
			
			for (i = 0; i<numSubGeoms; ++i){
				subGeom = SubGeometry(subGeometries[i]);
				indices = subGeom.indexData;
				normals = new Vector.<Number>();
				tangents = new Vector.<Number>();
				for (j = 0; j<indices.length; j+=3){
					indV0 = indices[j];
					indices[j] = indices[ind = j+1];
					indices[ind] = indV0;
				}
				
				subGeom.updateIndexData(indices);
				subGeom.updateVertexNormalData(normals);
				subGeom.updateVertexTangentData(tangents);
			}
		}
		
		/*public static function invertFaces1(mesh:Mesh):void
		{
			var subGeometries:Vector.<SubGeometry> = mesh.geometry.subGeometries;
			var numSubGeoms:uint = subGeometries.length;
			var sourceverts:Vector.<Number>;
			var indices:Vector.<uint>;
			var uvs:Vector.<Number>;
			
			var i:uint;
			var j:uint;
			var indV0:uint;
			var indV1:uint;
			var indUV0:uint;
			var indUV1:uint;
			
			var v0:Vertex = new Vertex();
			var v1:Vertex = new Vertex();
			
			var uv0:UV = new UV();
			var uv1:UV = new UV();
			
			var subGeom:SubGeometry;
			
			for (i = 0; i<numSubGeoms; ++i){
				subGeom = SubGeometry(subGeometries[i]);
				sourceverts = subGeom.vertexData;
				indices = subGeom.indexData;
				uvs = subGeom.UVData;
				
				for (j = 0; j<indices.length; j+=3){
					indV0 = indices[j]*3;
					indV1 = indices[j+1]*3;
					indUV0 = indices[j]*2;
					indUV1 = indices[j+1]*2;
					v0.x = sourceverts[indV0];
					v0.y = sourceverts[indV0+1];
					v0.z = sourceverts[indV0+2];
					
					uv0.u = uvs[indUV0];
					uv0.v = uvs[indUV0+1];
					 
					v1.x = sourceverts[indV1];
					v1.y = sourceverts[indV1+1];
					v1.z = sourceverts[indV1+2];
					
					uv1.u = uvs[indUV1];
					uv1.v = uvs[indUV1+1];
					
					sourceverts[indV0] = v1.x;
					sourceverts[indV0+1] = v1.y;
					sourceverts[indV0+2] = v1.z;
					
					sourceverts[indV1] = v0.x;
					sourceverts[indV1+1] = v0.y;
					sourceverts[indV1+2] = v0.z;
					 
					uvs[indUV0] = uv1.u;
					uvs[indUV0+1] = uv1.v;
					
					uvs[indUV1] = uv0.u;
					uvs[indUV1+1] = uv0.v;
					
					subGeom.updateVertexData(sourceverts);
					subGeom.updateUVData(uvs);
					 
				}
			}
		}*/
		
		/**
		* Build a Mesh from Vectors
		* @param vertices				Vector.<Number>. The vertices Vector.<Number>, must hold a multiple of 3 numbers.
		* @param indices				Vector.<uint>. The indices Vector.<uint>, holding the face order
		* @param uvs					[optional] Vector.<Number>. The uvs Vector, must hold a series of numbers of (vertices.length/3 * 2) entries. If none is set, default uv's are applied
		* if no uv's are defined, default uv mapping is set.
		* @param name					[optional] String. new name for the generated mesh. Default = "";
		* @param material				[optional] MaterialBase. new name for the duplicated mesh. Default = null;
		* @param shareVertices		[optional] Boolean. Defines if the vertices are shared or not. When true surface gets a smoother appearance when exposed to light. Default = true;
		* @param useDefaultMap	[optional] Boolean. Defines if the mesh receives the default engine map if no material is passes. Default = true;
		*/
		public static function build(vertices:Vector.<Number>, indices:Vector.<uint>, uvs:Vector.<Number> = null, name:String = "", material:MaterialBase = null, shareVertices:Boolean = true, useDefaultMap:Boolean = true):Mesh
		{
			if(uvs && (vertices.length/3)*2 < uvs.length)
				throw new Error("MeshHelper error: The vector uvs provided do not hold enough entries");
			
			var subGeom:SubGeometry = new SubGeometry();
			subGeom.autoDeriveVertexNormals = true;
			subGeom.autoDeriveVertexTangents = true;
			var geometry:Geometry = new Geometry();
			geometry.addSubGeometry(subGeom);
			
			material = (!material && useDefaultMap)? new BitmapMaterial(DefaultBitmapData.bitmapData) : material;
			var m:Mesh = new Mesh(material, geometry);
			
			if(name != "") m.name = name;
			
			var nvertices:Vector.<Number> = new Vector.<Number>();
			var nuvs:Vector.<Number> = new Vector.<Number>();
			var nindices:Vector.<uint> = new Vector.<uint>();
			
			var noUV:Boolean;
			
			if(!uvs){
				noUV = true;
				var defaultUVS:Vector.<Number> = Vector.<Number>([0, 1, .5, 0, 1, 1, .5, 0]);
				var uvid:uint;
			}
			
			var uvind:uint;
			var vind:uint;
			var ind:uint;
			var dub:Boolean;
			var i:uint;
			var j:uint;
			var lenv:uint;
			var tmpVind:uint;
			
			var vertex:Vertex = new Vertex();
			for (i = 0;i<indices.length;++i){
				ind = indices[i]*3;
				vertex.x = vertices[ind];
				vertex.y = vertices[ind+1];
				vertex.z = vertices[ind+2];
				lenv = nvertices.length;
				
				if(lenv +9 > LIMIT ){
					subGeom.updateVertexData(nvertices);
					subGeom.updateIndexData(nindices);
					subGeom.updateUVData(nuvs);
				
					subGeom = new SubGeometry();
					subGeom.autoDeriveVertexNormals = true;
					subGeom.autoDeriveVertexTangents = true;
					geometry.addSubGeometry(subGeom);
					
					vind =  uvind = lenv = 0;
					if(noUV) uvid = 0;
					nvertices = new Vector.<Number>();
					nindices = new Vector.<uint>();
					nuvs = new Vector.<Number>();
				}
				
				if(lenv>0 && shareVertices){
					dub = false;
					for(j = 0;j<nindices.length-3;++j){
						tmpVind = j*3;
						if(nvertices[tmpVind] == vertex.x && vertex.y == nvertices[tmpVind+1] && vertex.z == nvertices[tmpVind+2]){
							ind = j/3;
							nindices[nindices.length] = j;
							dub = true;
							break;
						}
					}
				}
				 
				if(dub) continue;
				 
				nvertices.push(vertex.x, vertex.y, vertex.z); 
				nindices[nindices.length] = i;
				
				if(noUV){
					nuvs.push(defaultUVS[uvid], defaultUVS[uvid+1]);
					uvid = (uvid+2>3)? 0 : uvid+=2;
					 
				} else{
					uvind = indices[i]*2;
					nuvs.push(uvs[uvind], uvs[uvind+1]); 
				}
			}
			 
			subGeom.updateVertexData(nvertices);
			subGeom.updateIndexData(nindices);
			subGeom.updateUVData(nuvs);
			
			return m;
		}
		 
		/**
		* unfinished: to do unique material checks, empty subgeometries & animation
		* Returns a mesh with its subgeometries reorganized 
		*/
		/*public static function compactData(m:Mesh) : Mesh
		{
			var geometries:Vector.<SubGeometry> = m.geometry.subGeometries;
			var numSubGeoms:int = geometries.length;
			
			var vertices:Vector.<Number> = new Vector.<Number>();
			var indices:Vector.<uint> = new Vector.<uint>();
			var uvs:Vector.<Number> =new Vector.<Number>();
			
			var subGeom:SubGeometry;
			var index:uint;
			var indexuv:uint;
			var indexind:uint;
			var offset:uint;
			
			var subvertices:Vector.<Number>;
			var subindices:Vector.<uint>;
			var subuvs:Vector.<Number>;
			
			var j : uint;
			var vecLength : uint;
			
			for (var i : uint = 0; i < numSubGeoms; ++i){
				subGeom = geometries[i];
				subvertices = subGeom.vertexData;
				vecLength = subvertices.length;
				for (j = 0; j < vecLength; ++j){
					vertices[index++] = subvertices[j];
				}
				
				subindices = subGeom.indexData;
				vecLength = subindices.length;
				for (j = 0; j < vecLength; ++j){
					indices[indexind++] = subindices[j]+offset;
				}
				offset +=vecLength;
				
				subuvs = subGeom.UVData;
				vecLength = subuvs.length;
				for (j = 0; j < vecLength; ++j){
					uvs[indexuv++] = subuvs[j];
				}
			}
			
			return build(vertices, uvs, m.name, m.material, true, false);
		}*/
	}
}