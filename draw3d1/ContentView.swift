//
//  ContentView.swift
//  draw3d1
//
//  Created by Apple1 on 3/25/21.
//

import SwiftUI
import RealityKit
import ARKit

typealias float=Float
typealias int=Int
typealias vec2=SIMD2<float>
typealias vec3=SIMD3<float>
typealias vec4=SIMD4<float>
typealias quat=simd_quatf

var isdrawing=false
var frameCount:int=0

enum drawmode:String,CaseIterable{
    case pen="pen"
    case line="line"
}

struct ContentView:View{
    @State var col=Color(red:1,green:0,blue:1)
    @State var zdist:float=0.4
    @State var mode:drawmode = .pen
    @State var scale:float=0.01
    var tap: some Gesture {
        TapGesture(count: 1)
        .onEnded{_ in isdrawing = !isdrawing}
    }
    var body:some View{
        let arvc=ARViewContainer(col:$col,zdist:$zdist,scale:$scale,mode:$mode)
        VStack{
            arvc.gesture(tap).edgesIgnoringSafeArea(.all)
            Spacer()
            HStack{
                Spacer()
                Button("draw"){isdrawing = !isdrawing}
                Spacer()
                Button("undo",action:arvc.undo)
                Spacer()
                Button("clear",action:arvc.clear)
                Spacer()
            }
            VStack{
                ColorPicker("color:",selection:$col);
                HStack{
                    Text("depth:")
                    Slider(value:$zdist,in: 0...1)
                }
                HStack{
                    Text("scale:")
                    Slider(value:$scale,in: 0...0.05)
                }
                Picker("draw mode",selection:$mode){
                    ForEach(drawmode.allCases,id:\.self){
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    
    }
}


struct ARViewContainer:UIViewRepresentable{
    let arView=ARView(frame: .zero)
    let cam=Entity()
    let cont=Entity()
    var del=ardelegate()
    let boxAnchor=AnchorEntity()
    var col:Binding<Color>
    var zdist:Binding<float>
    var scale:Binding<float>
    var mode:Binding<drawmode>
    let cambox=Entity()
    let cursor=ModelEntity()
    func makeUIView(context: Context)->ARView{
        boxAnchor.addChild(cam)
        boxAnchor.addChild(cont)
        cam.transform=arView.cameraTransform
        cam.addChild(cambox)
        let mat=SimpleMaterial()
        cambox.addChild(cursor)
        cursor.model=ModelComponent(mesh:MeshResource.generateSphere(
                                        radius:1),
                                    materials: [mat])
        cambox.setPosition(vec3(0,0,-0.4), relativeTo:cam)
        cont.setPosition(vec3(0,0,0), relativeTo:boxAnchor)
        arView.scene.anchors.append(boxAnchor)
        del.arvc=self
        arView.session.delegate=del
        return arView
    }
    func clear(){
        del.undos.reset()
        cont.children.removeAll()
    }
    func undo(){
        let delat=del.undos.pop()
        let end=cont.children.count
        for _ in delat..<end{
            cont.children.remove(at:delat)
        }
    }
    func updateUIView(_ uiView:ARView,context:Context){}
}

struct stack{
    var mem:[int]=[]
    var sp:int = -1
    init(){}
    mutating func push(_ x:int){
        sp+=1
        if sp>=mem.count{ mem.append(0)}
        mem[sp]=x
    }
    mutating func pop()->int{
        if sp<0{ return 0}
        let x=mem[sp]
        sp=max(sp-1,-1)
        return x
    }
    mutating func reset(){
        sp = -1
        mem=[]
    }
}



class ardelegate:NSObject,ARSessionDelegate{
    var arvc:ARViewContainer?
    var prev=false
    var point:Entity?
    var line:ModelEntity?
    var undos=stack()
    func session(_:ARSession,didUpdate:ARFrame){
        let ar=arvc!
        ar.cam.transform=ar.arView.cameraTransform
        ar.cambox.setPosition(vec3(0,0,-ar.zdist.wrappedValue), relativeTo: ar.cam)
        let mat=SimpleMaterial(color: UIColor(ar.col.wrappedValue),
                               isMetallic:false)
        ar.cursor.model?.materials[0]=mat
        let radius=ar.scale.wrappedValue
        let scalemtx=float4x4(vec4(radius,0,0,0),
                              vec4(0,radius,0,0),
                              vec4(0,0,radius,0),
                              vec4(0,0,0,1))
        ar.cursor.transform=Transform(matrix:scalemtx)
        if isdrawing{
            let m=ar.cambox.transform.matrix
            switch ar.mode.wrappedValue{
                case .pen:
                    if !prev{
                        undos.push(ar.cont.children.count)
                    }
                    let box=ModelEntity()
                    ar.cont.addChild(box)
                    
                    box.model=ModelComponent(mesh:MeshResource.generateBox(size: 2*radius),
                                           materials: [mat])
                    box.transform=Transform(matrix:ar.cam.transform.matrix*m)
                    break
                case .line:
                    if !prev{
                        undos.push(ar.cont.children.count)
                        point=Entity()
                        line=ModelEntity()
                        ar.cont.addChild(line!)
                        ar.cont.addChild(point!)
                        line!.model=ModelComponent(mesh:MeshResource.generateBox(size: 2*radius),
                                               materials: [mat])
                        line!.transform=Transform(matrix:
                            ar.cam.transform.matrix*m)
                        point!.transform=Transform(matrix:
                            ar.cam.transform.matrix*m)
                        break
                    }
                    let p=Transform(matrix:ar.cam.transform.matrix*m).translation
                    let start=Transform(matrix:point!.transform.matrix).translation
                    line!.model=ModelComponent(mesh:MeshResource.generateBox(
                                               size:vec3(2*radius,length(p-start),2*radius)),
                                               materials: [mat])
                    let off=(start-p)/2.0
                    let q=quat(from:vec3(0,1,0),to:normalize(p-start))
                    let offmtx=float4x4(vec4(1,0,0,0),
                                        vec4(0,1,0,0),
                                        vec4(0,0,1,0),
                                        vec4(off.x,off.y,off.z,1))
                    let rot=float4x4(q)
                    line!.transform=Transform(matrix:
                        ar.cam.transform.matrix*m*offmtx*rot)
                    break
            }
        }
        prev=isdrawing
        frameCount+=1
    }
}




