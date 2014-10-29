import 'dart:html';
import 'dart:convert';

String registryHost = "localhost";
String registryPort = "8000";
String baseUri = "http://$registryHost:$registryPort/registry/systems";

void main() {
  fetchNodes();
}

void fetchNodes() {
  var url = "$baseUri/list";
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
  for(Element e in elementList) {
    e.onClick.listen((MouseEvent event) {
      print("Clicked -> ${e.id}");
      _setSelectedNode(e);
      _clear(querySelector('#systemsList'));
      _clear(querySelector('#detailsInfo'));
      _fetchRunningSystems(e.id);
    });
  }
}

void _fetchRunningSystems(String id) {
  var url = "$baseUri/$id";
  var request = HttpRequest.getString(url).then(_onSystemsFetched);
}

void _onSystemsFetched(responseText) {
  Map systems = JSON.decode(responseText);
  print(systems);
  StringBuffer elements = new StringBuffer();
  for(String systemName in systems.keys) {

    StringBuffer workers = new StringBuffer();
    for(Map worker in systems[systemName]) {
      workers.write('''<li id="${worker['name']}">${worker['name']}
                      <ul class="hidden details">
                        <li>Name: ${worker['name']}</li>
                        <li>Source Uri: ${worker['uri']}</li>
                        <li>No. of Instances: ${JSON.decode(worker['paths']).length}</li>
                        <li>Deployed paths: ${worker['paths']}</li>
                        <li>RouterType: ${worker['routerType']}</li>
                        <li>HotDeployment: ${worker['hotDeployment']}</li>
                      </ul></li>''');
    }

    elements.write('''<li id = '$systemName'>
                        $systemName:
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
        print("Clicked -> ${e.id}");
        _setSelectedSystem(e);
        _displayDetails(e.querySelector(".details"));
      });
    }
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
    print('CLEARING');
    e.remove();
  } else {
    print("$e is null");
  }
}
