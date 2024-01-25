//
//  EmojiArtDocumentView.swift
//  Emoji Art
//
//  Created by CS193p Instructor on 5/8/23.
//  Copyright (c) 2023 Stanford University
//

import SwiftUI

struct EmojiArtDocumentView: View {
    typealias Emoji = EmojiArt.Emoji
    
    @ObservedObject var document: EmojiArtDocument
    @State var selectedEmojis: Set<Int> = []
    @State var isDeleteOn = false
    
    private let paletteEmojiSize: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                deleteButton
                Spacer()
            }.padding(5)
            
            documentBody
            PaletteChooser()
                .font(.system(size: paletteEmojiSize))
                .padding(.horizontal)
                .scrollIndicators(.hidden)
        }
        .onTapGesture {
            selectedEmojis.removeAll()
        }
    }
    
    private var deleteButton: some View {
        Button(action: {
            isDeleteOn.toggle()
        }, label: {
            Text("Delete")
                .background{
                    RoundedRectangle(cornerRadius: 4)
                        .foregroundStyle(!isDeleteOn ? .red : .init(hue: 0.97, saturation: 0.4, brightness: 0.8))
                        .padding(EdgeInsets(top: -2, leading: -4, bottom: -2, trailing: -4))
                }
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
        })
    }
    
    private var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                documentContents(in: geometry)
                    .scaleEffect(zoom * gestureZoom)
                    .offset(pan + gesturePan)
            }
            .gesture(selectedEmojis.isEmpty ? nil : scaleEmojiGesture)
            .gesture(selectedEmojis.isEmpty ? panGesture.simultaneously(with: zoomGesture) : nil)
            .dropDestination(for: Sturldata.self) { sturldatas, location in
                return drop(sturldatas, at: location, in: geometry)
            }
        }
    }
    
    @ViewBuilder
    private func documentContents(in geometry: GeometryProxy) -> some View {
        AsyncImage(url: document.background)
            .position(Emoji.Position.zero.in(geometry))
        ForEach(document.emojis) { emoji in
            Text(emoji.string)
                .padding(2)
                .border(.blue, width: selectedEmojis.contains(emoji.id) ? 2 : 0)
                .font(emoji.font)
                .overlay(alignment: .topLeading) {
                    Image(systemName:"minus.circle.fill")
                        .foregroundStyle(isDeleteOn ? .red : .clear)
                        .fontWeight(.light)
                        .onTapGesture {
                            if isDeleteOn {
                                selectedEmojis.remove(emoji.id)
                                document.removeEmoji(emoji)
                            }
                        }
                        .padding(.trailing, 2)
                }
                .position(emoji.position.in(geometry))
                .scaleEffect(selectedEmojis.contains(emoji.id) ? gestureEmojiScale : 1)
                .offset(selectedEmojis.contains(emoji.id) ? gestureEmojiMove : CGOffset())
                .onTapGesture {
                    if (selectedEmojis.remove(emoji.id) == nil) {
                        selectedEmojis.insert(emoji.id)
                    }
                }
                .gesture(selectedEmojis.isEmpty ? nil : moveEmojiGesture)
        }
    }
    @State private var emojiScale: CGFloat = 1
    @State private var emojiPan: CGOffset = .zero
    
    @GestureState private var gestureEmojiScale: CGFloat = 1
    @GestureState private var gestureEmojiMove: CGOffset = .zero
    
    private var scaleEmojiGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureEmojiScale) { inMotionPinchScale, gestureEmojiScale, _ in
                gestureEmojiScale = inMotionPinchScale
            }
            .onEnded { endingPinchScale in
                updateEmojiSize(by: endingPinchScale)
            }
    }
    
    private var moveEmojiGesture: some Gesture {
        DragGesture()
            .updating($gestureEmojiMove) { inMotionDragGestureValue, gestureEmojiMove, _ in
                gestureEmojiMove = inMotionDragGestureValue.translation
            }
            .onEnded { endingDragGestureValue in
                updateEmojiPositions(by: endingDragGestureValue.translation)
            }
    }
    
    func updateEmojiSize(by gestureScale: CGFloat) {
        for emojiID in selectedEmojis {
            document.resize(emojiWithId: emojiID, by: gestureScale)
        }
    }
    
    func updateEmojiPositions(by gestureMove: CGOffset) {
        for emojiID in selectedEmojis {
            document.move(emojiWithId: emojiID, by: gestureMove)
        }
    }

    @State private var zoom: CGFloat = 1
    @State private var pan: CGOffset = .zero
    
    @GestureState private var gestureZoom: CGFloat = 1
    @GestureState private var gesturePan: CGOffset = .zero
    
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureZoom) { inMotionPinchScale, gestureZoom, _ in
                gestureZoom = inMotionPinchScale
            }
            .onEnded { endingPinchScale in
                zoom *= endingPinchScale
            }
    }
    
    private var panGesture: some Gesture {
        DragGesture()
            .updating($gesturePan) { inMotionDragGestureValue, gesturePan, _ in
                gesturePan = inMotionDragGestureValue.translation
            }
            .onEnded { endingDragGestureValue in
                pan += endingDragGestureValue.translation
            }
    }
    
    private func drop(_ sturldatas: [Sturldata], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        for sturldata in sturldatas {
            switch sturldata {
            case .url(let url):
                document.setBackground(url)
                return true
            case .string(let emoji):
                document.addEmoji(
                    emoji,
                    at: emojiPosition(at: location, in: geometry),
                    size: paletteEmojiSize / zoom
                )
                return true
            default:
                break
            }
        }
        return false
    }
    
    private func emojiPosition(at location: CGPoint, in geometry: GeometryProxy) -> Emoji.Position {
        let center = geometry.frame(in: .local).center
        return Emoji.Position(
            x: Int((location.x - center.x - pan.width) / zoom),
            y: Int(-(location.y - center.y - pan.height) / zoom)
        )
    }
}

struct EmojiArtDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
            .environmentObject(PaletteStore(named: "Preview"))
    }
}
