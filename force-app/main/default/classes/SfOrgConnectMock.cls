@isTest
public class SfOrgConnectMock implements HttpCalloutMock {
    private List<HttpResponse> responses = new List<HttpResponse>();
    private Integer index = 0;

    public SfOrgConnectMock add(Integer statusCode, String body) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setHeader('Content-Type', 'text/xml');
        res.setBody(body);
        responses.add(res);
        return this;
    }

    public HTTPResponse respond(HTTPRequest req) {
        if (responses.isEmpty()) {
            HttpResponse empty = new HttpResponse();
            empty.setStatusCode(500);
            empty.setBody('No mock response queued');
            return empty;
        }
        Integer useIndex = index < responses.size() ? index : responses.size() - 1;
        index++;
        return responses[useIndex];
    }
}
