//
//  ContentView.swift
//  Shared
//
//  Created by Muhammad Shahmeer Athar on 2021-10-23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = ImagesViewModel()
    
    var body: some View {
        VStack {
            Text("No Fences Please!")
                .padding()
                .font(.title)
            List(model.display_images.indices) { index in
                if let image = model.display_images[index] {
                    ImageView(image: image)
                }
            }
            
        }
        .onAppear(perform: model.fetchImages)
    }
}

struct ImageView: View {
    @State private var image: Image
    
    var body: some View {
        image
    }
    
    init(image: Image) {
        self.image = image
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
