/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import RxSwift
import RxCocoa
import Kingfisher


func cachedFileURL(_ fileName: String) -> URL {
    return FileManager.default
        .urls(for: .cachesDirectory, in: .allDomainsMask)
        .first!
        .appendingPathComponent(fileName)
}

class ActivityController: UITableViewController {

  let repo = "ReactiveX/RxSwift"

  fileprivate let events = Variable<[Event]>([])
  fileprivate let bag = DisposeBag()
    
  private let eventsFileURL = cachedFileURL("events.plist")
  private let modifiedFileURL = cachedFileURL("modified.txt")
    
  fileprivate let lastModified = Variable<NSString?>(nil)
    
  override func viewDidLoad() {
    super.viewDidLoad()
    title = repo

    self.refreshControl = UIRefreshControl()
    let refreshControl = self.refreshControl!

    refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
    refreshControl.tintColor = UIColor.darkGray
    refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
    refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)

    let eventsArray = (NSArray(contentsOf: eventsFileURL) as? [AnyDict]) ?? []
    events.value = eventsArray.flatMap(Event.init)
    
    
    lastModified.value = try? NSString(contentsOf: modifiedFileURL, usedEncoding: nil)
    refresh()
  }

  func refresh() {
    fetchEvents(repo: repo)
  }

  func fetchEvents(repo: String) {
    
    let _ = Observable.from([repo,"yea"])
                .map({ (urlString:String) -> URL in
                        return URL(string:  "https://api.github.com/repos/\(urlString)/events")!})
        .map{ url -> URLRequest in URLRequest(url: url) }
        .flatMap{
                    request -> Observable<(HTTPURLResponse,Data)> in
                            return URLSession.shared.rx.response(request: request)}
         .filter{ response, _ in
                        return 200..<300 ~= response.statusCode}
        .map{ _,data -> [[String: Any]] in
            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                  let result = jsonObject as? [[String: Any]] else{ return [] }
            return result
            }
        .filter{ objects in return objects.count > 0 }
        .map{ objects in return objects.flatMap(Event.init)}
        .subscribe(onNext:{ [weak self] newEvents in
            self?.processEvents(newEvents)
        } ).addDisposableTo(bag)
    
    
    
    
    
  }
    
 
    
    
    
    func processEvents(_ newEvents: [Event])  {
        var updatedEvents = newEvents + events.value
        if updatedEvents.count > 50 {
            updatedEvents = Array<Event> (updatedEvents.prefix(upTo:50))
        }
        events.value = updatedEvents
        
        DispatchQueue.main.async {
             self.tableView.reloadData()
             self.refreshControl?.endRefreshing()
        }
        
        
        let eventsArray = updatedEvents.map{ $0.dictionary} as NSArray
        eventsArray.write(to: eventsFileURL, atomically: true)
       
    }

  // MARK: - Table Data Source
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return events.value.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let event = events.value[indexPath.row]

    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
    cell.textLabel?.text = event.name
    cell.detailTextLabel?.text = event.repo + ", " + event.action.replacingOccurrences(of: "Event", with: "").lowercased()
    cell.imageView?.kf.setImage(with: event.imageUrl, placeholder: UIImage(named: "blank-avatar"))
    return cell
  }
}
