import 'dart:html';
import 'dart:convert';

 //String registryHost = "localhost";
 //String registryPort = "8000";
 //String baseUri = "http://$registryHost:$registryPort/registry";

String baseUri = "";

void main() {
  baseUri = Uri.parse(document.baseUri).queryParameters['host'];
  fetchNodes();
  querySelector("#addWorkerButton").onClick.listen(_showAddWorkerForm);
  querySelector("#closeButton").onClick.listen(_closeAddWorkerForm);
  querySelector("#submit").onClick.listen(_addWorker);
  querySelector("#submitToAll").onClick.listen(_addWorkerToAllNodes);
}

void fetchNodes() {
  var url = "$baseUri/system/list";
  var request = HttpRequest.getString(url).then(_onNodesFetched);
}

void _onNodesFetched(responseText) {
  List<Map> nodes = JSON.decode(responseText);
  StringBuffer elements = new StringBuffer();
  for(Map node in nodes) {
    elements.write("<li id='${node['bootstrapperId']}'>${node['ip']}:${node['port']}</li>");
  }

  _clear(querySelector("#nodeList li"));

  querySelector("#nodeList").appendHtml(elements.toString());

  List<Element> elementList = querySelectorAll('#nodeList li');
  querySelector("#nodes .header h1").appendText(" (${elementList.length} nodes)");
  for(Element e in elementList) {
    e.onClick.listen((MouseEvent event) {
      _setSelectedNode(e);
      _fetchRunningSystems(e.id);
    });
  }
}

void _fetchRunningSystems(String id) {
  _clear(querySelector('#systemsList'));
  _clear(querySelector('#detailsInfo'));
  var url = "$baseUri/system/$id";
  var request = HttpRequest.getString(url).then(_onSystemsFetched);
}

void _onSystemsFetched(responseText) {
  _clear(querySelector('#systemsList'));
  _clear(querySelector('#detailsInfo'));
  //print("Systems Fetched : $responseText");
  Map systems = JSON.decode(responseText);
  //print("Systems Fetched decoded : $systems");
  StringBuffer elements = new StringBuffer();
  for(String systemName in systems.keys) {

    StringBuffer workers = new StringBuffer();
    for(Map worker in systems[systemName]) {
      workers.write('''<li id="${worker['id']}">${worker['id']} <span class="removeIsolate" title="Remove this isolate from this isolate system">Kill</span>
                      <ul class="hidden details">
                        <li>Name: ${worker['id']}</li>
                        <li>Source Uri: ${worker['workerUri']}</li>
                        <li>No. of Instances: ${worker['workersPaths'].length}</li>
                        <li>Deployed paths: ${worker['workersPaths']}</li>
                        <li>RouterType: ${worker['routerType']}</li>
                        <li>HotDeployment: ${worker['hotDeployment']}</li>
                      </ul></li>''');
    }

    elements.write('''<li id = '$systemName'>
                        $systemName: <div class="removeSystem" title="Shutdown the Isolate System and all isolates in it">Shutdown</div>
                        <ul>
                            $workers
                        </ul>
                      </li>''');
  }

  querySelector('#systems .contents').appendHtml('''<ul id='systemsList'> ${elements.toString()}</ul>''');

  ElementList elementList = querySelectorAll('#systemsList li ul li');
  for(Element e in elementList) {
    if(e != null) {
      e.onClick.listen((MouseEvent event) {
        _setSelectedSystem(e);
        _displayDetails(e.querySelector(".details"));
      });
    }
  }

  ElementList systemsList = querySelectorAll('#systemsList li .removeSystem');
  for(Element systemElem in systemsList) {
    if(systemElem != null) {
      systemElem.onClick.listen((MouseEvent event) {
        _shutdownIsolateSystem(event, systemElem);
      });
    }
  }

  ElementList isolateList = querySelectorAll('.removeIsolate');
  for(Element isolateElem in isolateList) {
    isolateElem.onClick.listen((MouseEvent event) {
      _killIsolate(event, isolateElem);
    });
  }

}

void _displayDetails(Element e) {
  _clear(querySelector('#detailsInfo'));
  String details = '''
                    <ul id="detailsInfo">
                      ${e.innerHtml}
                    </li>
                    ''';
  querySelector('#details .contents').appendHtml(details);
}

void _setSelectedNode(Element e) {
  for(Element child in e.parent.children) {
    child.classes.remove('selected');
  }
  e.classes.add('selected');
}

void _setSelectedSystem(Element e) {
  ElementList elements = querySelectorAll('#systemsList li ul li');
  for(Element element in elements) {
    element.classes.remove('selected');
  }
  e.classes.add('selected');
}

void _clear(Element e) {
  if(e != null) {
    e.remove();
  }
}

void _showAddWorkerForm(MouseEvent e) {
  Element selectedNode = querySelector("#nodeList .selected");
  if(selectedNode == null) {
    window.alert("Please select a Node !");
  } else {
    String id = selectedNode.id;
    querySelector("#bootstrapperId").value = id;
    querySelector("#overlay").classes.remove('hidden');
    querySelector("#isolateSystemName").focus();
    window.onKeyDown.listen((KeyEvent k) {
      if(k.keyCode == KeyCode.ESC) {
        _closeAddWorkerForm(null);
      }
    });
  }
}

void _closeAddWorkerForm(MouseEvent e) {
  querySelector("#overlay").classes.add('hidden');
}

void _addWorker(MouseEvent e) {
  FormElement form = querySelector("#addWorkerForm");
  Map formData = serializeForm(form);
  _sendRequest(formData);
  /*
  String nodeId = formData['bootstrapperId'];
  _closeAddWorkerForm(null);
  _fetchRunningSystems(nodeId);
  */
}

void _addWorkerToAllNodes(MouseEvent e) {
  FormElement form = querySelector("#addWorkerForm");
  Map formData = serializeForm(form);

  ElementList nodes = querySelectorAll("#nodeList li");
  for(Element node in nodes.toList()) {
    print(node.id);
    formData['bootstrapperId'] = node.id;
    _sendRequest(formData);
  }
}

void _sendRequest(Map formData) {
  var url = "$baseUri/deploy";
  HttpRequest request = new HttpRequest();
  request.open("POST", url, async:false);
  request.setRequestHeader("Content-type", "application/json");
  print(JSON.encode(formData));
  request.send(JSON.encode(formData));
  window.location.reload();
}

void _shutdownIsolateSystem(MouseEvent e, Element el) {
  String nodeId = querySelector("#nodeList .selected").id;
  String systemName = el.parent.id;
  bool confirm = window.confirm("Do you really want to\nshutdown Isolate System: \"${systemName}\"?");
  if(confirm) {
    _postShutdownRequest(nodeId, systemName);
    _fetchRunningSystems(nodeId);
  }
}

void _killIsolate(MouseEvent e, Element isolateElement) {
  String nodeId = querySelector("#nodeList .selected").id;
  String systemName = isolateElement.parent.parent.parent.id;
  String isolateName = isolateElement.parent.id;
  bool confirm = window.confirm("Do you really want to\nkill isolate \"$isolateName\"\nof\nIsolate System \"$systemName\"?");
  if(confirm) {
    _postShutdownRequest(nodeId, systemName, isolateName:isolateName);
    _fetchRunningSystems(nodeId);
  }
}

void _postShutdownRequest(String nodeId, String systemName, {String isolateName}) {
  Map data = {'bootstrapperId':nodeId, 'isolateSystemName':systemName};
  if(isolateName != null) {
    data['isolateName'] = isolateName;
  }
  var url = "$baseUri/system/shutdown";
  HttpRequest request = new HttpRequest();
  request.open("POST", url, async:false);
  request.setRequestHeader("Content-type", "application/json");
  request.send(JSON.encode(data));
}

_onDeployed(var responseText, FormElement form) {
  _clearForm(form);
}

_clearForm(FormElement form) {
  for(var el in form.querySelectorAll("input, select")) {
    if(el is InputElement) {
      el.value = null;
    }
  }
}

serializeForm(FormElement form) {
  Map data = {};

  form.querySelectorAll("input,select").forEach((Element el) {
    if(el is InputElement) {
      if(el.id == "hotDeployment") {
        data[el.id] = false;
        if(el.checked) {
          data[el.id] = true;
        }
      } else if(el.id == "workersPaths") {
        List<String> paths = el.value.trim().split(',');
        for(int i = 0; i < paths.length; i++) {
          paths[i] = paths[i].trim();
        }
        data[el.id] = paths;
      } else {
        data[el.id] = el.value;
      }
    }
  });

  return data;
}
