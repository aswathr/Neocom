//
//  SearchView.swift
//  Neocom
//
//  Created by Artem Shimanski on 11/27/19.
//  Copyright © 2019 Artem Shimanski. All rights reserved.
//

import SwiftUI
import Combine

class SearchController<Results, Predicate>: ObservableObject {
    @Published var results: Results
    @Published var predicate: Predicate
    var onUpdated: ((Predicate) -> Void)?
    
    private var subscription: AnyCancellable?
    
    init<P>(initialValue value: Results, predicate: Predicate, _ search: @escaping (Predicate) -> P, onUpdated: ((Predicate) -> Void)? = nil) where P: Publisher, P.Output == Results, P.Failure == Never {
        self._results = Published(initialValue: value)
        self._predicate = Published(initialValue: predicate)
        self.onUpdated = onUpdated
        
        subscription = $predicate.debounce(for: .seconds(0.25), scheduler: DispatchQueue.main)
            .flatMap {
                search($0).zip(Just($0))
        }
            .sink { [weak self] in
                self?.onUpdated?($0.1)
                self?.results = $0.0
        }
    }
}

struct SearchView<Results: Publisher, Content: View, Output>: View where Results.Failure == Never, Results.Output == Output? {
    @ObservedObject private var searchResults: SearchController<Results.Output, String>
    @State var isEditing: Bool = false
    
    var content: (Results.Output) -> Content
    
    init(initialValue: Results.Output, predicate: String = "", search: @escaping (String) -> Results, onUpdated: ((String) -> Void)? = nil, @ViewBuilder content: @escaping (Results.Output) -> Content) {
        self.content = content
        searchResults = SearchController(initialValue: initialValue, predicate: predicate, search, onUpdated: onUpdated)
    }
        
    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $searchResults.predicate, isEditing: $isEditing)
            ZStack {
                content(searchResults.results)
                if searchResults.results == nil && isEditing {
                    Color(.systemFill).edgesIgnoringSafeArea(.all).transition(.opacity)
                }
            }
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SearchView(initialValue: nil, search: { string in
                Just(string)
            }) { results in
                List {
                    if results == nil {
                        ForEach(0..<100) { _ in
                            Text("Item")
                        }
                    }
                    else {
                        Text(results!)
                    }
                }
            }.navigationBarTitle("Title")
        }
    }
}
