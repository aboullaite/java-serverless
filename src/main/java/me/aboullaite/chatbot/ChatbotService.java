package me.aboullaite.chatbot;

import dev.langchain4j.chain.ConversationalRetrievalChain;
import dev.langchain4j.data.document.Document;
import dev.langchain4j.data.document.loader.UrlDocumentLoader;
import dev.langchain4j.data.document.parser.TextDocumentParser;
import dev.langchain4j.data.document.splitter.DocumentSplitters;
import dev.langchain4j.data.document.transformer.HtmlTextExtractor;
import dev.langchain4j.data.segment.TextSegment;
import dev.langchain4j.model.input.PromptTemplate;
import dev.langchain4j.model.vertexai.VertexAiChatModel;
import dev.langchain4j.model.vertexai.VertexAiEmbeddingModel;
import dev.langchain4j.retriever.EmbeddingStoreRetriever;
import dev.langchain4j.store.embedding.EmbeddingStoreIngestor;
import dev.langchain4j.store.embedding.inmemory.InMemoryEmbeddingStore;
import java.io.FileNotFoundException;
import java.net.MalformedURLException;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.Path;
import java.nio.file.Paths;
import org.springframework.stereotype.Service;
import org.springframework.util.ResourceUtils;

@Service
public class ChatbotService {

    public ConversationalRetrievalChain BuildRag() {

        URL url = null;
        try {
            url = new URL("https://dev.java/learn/");
        } catch (MalformedURLException e) {
            throw new RuntimeException(e);
        }
        Document htmlDocument = UrlDocumentLoader.load(url, new TextDocumentParser());
        HtmlTextExtractor transformer = new HtmlTextExtractor("#learn", null, false);
        Document document = transformer.transform(htmlDocument);

        VertexAiEmbeddingModel embeddingModel = VertexAiEmbeddingModel.builder()
            .endpoint("us-central1-aiplatform.googleapis.com:443")
            .project("mohamed-playground")
            .location("us-central1")
            .publisher("google")
            .modelName("textembedding-gecko@003")
            .maxRetries(3)
            .build();

        InMemoryEmbeddingStore<TextSegment> embeddingStore =
            new InMemoryEmbeddingStore<>();

        EmbeddingStoreIngestor storeIngestor = EmbeddingStoreIngestor.builder()
            .documentSplitter(DocumentSplitters.recursive(500, 100))
            .embeddingModel(embeddingModel)
            .embeddingStore(embeddingStore)
            .build();
        storeIngestor.ingest(document);

        EmbeddingStoreRetriever retriever = EmbeddingStoreRetriever.from(embeddingStore, embeddingModel);

        VertexAiChatModel model = VertexAiChatModel.builder()
            .endpoint("us-central1-aiplatform.googleapis.com:443")
            .project("mohamed-playground")
            .location("us-central1")
            .publisher("google")
            .modelName("chat-bison@001")
            .maxOutputTokens(1000)
            .build();

        ConversationalRetrievalChain rag = ConversationalRetrievalChain.builder()
            .chatLanguageModel(model)
            .retriever(retriever)
            .promptTemplate(PromptTemplate.from("""
                Answer to the following query the best as you can: {{question}}
                Base your answer on the information provided below and reference as much links from the reference as possible:
                {{information}}
                
                """
            ))
            .build();

        return rag;
    }

    private static Path toPath(String fileName) {
        try {
            URL fileUrl = ResourceUtils.getURL("classpath:" + fileName);
            return Paths.get(fileUrl.toURI());
        } catch (FileNotFoundException e) {
            throw new RuntimeException(e);
        } catch (URISyntaxException e) {
            throw new RuntimeException(e);
        }
    }
}
